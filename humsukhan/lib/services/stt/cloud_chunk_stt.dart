import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../audio/pcm_source.dart';
import '../supabase_service.dart';

/// Cuts a 16 kHz mono PCM16 stream into utterances at pauses.
///
/// Audio is measured in 100 ms frames. An utterance starts at the first loud
/// frame (keeping a little audio from just before it, so the first syllable
/// is not clipped), ends after [endOfUtterance] of quiet, and is cut at
/// [maxUtterance] so a long monologue still produces captions as it goes.
/// Bursts with less than [minSpeech] of sound are discarded as noise.
class UtteranceSegmenter {
  UtteranceSegmenter({
    required this.onUtterance,
    this.speechRms = 0.012,
    this.endOfUtterance = const Duration(milliseconds: 700),
    this.maxUtterance = const Duration(seconds: 12),
    this.minSpeech = const Duration(milliseconds: 300),
  });

  static const int _frameSamples = 1600; // 100 ms at 16 kHz
  static const int _preRollFrames = 3;

  final void Function(Uint8List pcm) onUtterance;
  final double speechRms;
  final Duration endOfUtterance;
  final Duration maxUtterance;
  final Duration minSpeech;

  final BytesBuilder _pending = BytesBuilder(copy: false);
  final List<Uint8List> _preRoll = [];
  final BytesBuilder _utterance = BytesBuilder();
  bool _inSpeech = false;
  int _framesInUtterance = 0;
  int _voicedFrames = 0;
  int _trailingQuietFrames = 0;

  int get _endFrames => endOfUtterance.inMilliseconds ~/ 100;
  int get _maxFrames => maxUtterance.inMilliseconds ~/ 100;
  int get _minVoicedFrames => math.max(1, minSpeech.inMilliseconds ~/ 100);

  void add(Uint8List bytes) {
    _pending.add(bytes);
    final available = _pending.takeBytes();
    var offset = 0;
    const frameBytes = _frameSamples * 2;
    while (available.length - offset >= frameBytes) {
      _frame(Uint8List.sublistView(available, offset, offset + frameBytes));
      offset += frameBytes;
    }
    if (offset < available.length) _pending.add(Uint8List.sublistView(available, offset));
  }

  /// Emits whatever has been heard so far, e.g. when listening stops.
  void flush() {
    if (_inSpeech) _finish();
    _preRoll.clear();
  }

  void _frame(Uint8List frame) {
    final loud = rms(frame) >= speechRms;
    if (!_inSpeech) {
      if (!loud) {
        _preRoll.add(Uint8List.fromList(frame));
        if (_preRoll.length > _preRollFrames) _preRoll.removeAt(0);
        return;
      }
      _inSpeech = true;
      for (final early in _preRoll) {
        _utterance.add(early);
        _framesInUtterance++;
      }
      _preRoll.clear();
    }
    _utterance.add(frame);
    _framesInUtterance++;
    if (loud) {
      _voicedFrames++;
      _trailingQuietFrames = 0;
    } else {
      _trailingQuietFrames++;
    }
    if (_trailingQuietFrames >= _endFrames || _framesInUtterance >= _maxFrames) _finish();
  }

  void _finish() {
    final audio = _utterance.takeBytes();
    final voiced = _voicedFrames;
    _inSpeech = false;
    _framesInUtterance = 0;
    _voicedFrames = 0;
    _trailingQuietFrames = 0;
    if (voiced >= _minVoicedFrames) onUtterance(audio);
  }

  /// RMS of PCM16 little-endian bytes, on a 0–1 scale.
  static double rms(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final samples = bytes.length ~/ 2;
    if (samples == 0) return 0;
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768;
      sum += s * s;
    }
    return math.sqrt(sum / samples);
  }
}

class CloudChunkResult {
  const CloudChunkResult({required this.text, required this.confidence, required this.language});
  final String text;
  final double confidence;

  /// 'English' or 'Urdu'.
  final String language;
}

/// Calls a Supabase Edge Function and returns its JSON body, or throws.
typedef EdgeFunctionInvoker = Future<Object?> Function(String function, Map<String, dynamic> body);

/// Speech recognition by recorded utterance, through the `deepgram-transcribe`
/// Edge Functions.
///
/// The backup for a phone whose own recognizer has no model for the language
/// being spoken, when the live streaming recognizer is unavailable too: each
/// utterance is sent as it ends, so captions arrive a moment after the
/// speaker pauses rather than word by word. Auto mode uses
/// `deepgram-transcribe-bilingual`; a fixed language uses `deepgram-transcribe`.
class CloudChunkStt {
  CloudChunkStt({PcmSource Function()? source, EdgeFunctionInvoker? invoke})
      : _newSource = source ?? RecorderPcmSource.new,
        _invoke = invoke ?? _invokeSupabase;

  static const singleLanguageFunction = 'deepgram-transcribe';
  static const bilingualFunction = 'deepgram-transcribe-bilingual';

  final PcmSource Function() _newSource;
  final EdgeFunctionInvoker _invoke;
  final StreamController<CloudChunkResult> _results = StreamController.broadcast();

  PcmSource? _source;
  StreamSubscription<Uint8List>? _audio;
  UtteranceSegmenter? _segmenter;
  Future<void> _queue = Future.value();
  String _language = 'auto';
  bool _listening = false;
  int _session = 0;
  String? _lastStartError;

  Stream<CloudChunkResult> get onResult => _results.stream;
  bool get isListening => _listening;
  String? get lastStartError => _lastStartError;

  /// [language] is 'Auto', 'English', 'Urdu' or 'Roman Urdu'.
  Future<bool> start({required String language}) async {
    if (_listening) return true;
    _lastStartError = null;
    final session = ++_session;
    _language = switch (language.toLowerCase()) {
      'urdu' || 'roman urdu' => 'urdu',
      'english' => 'english',
      _ => 'auto',
    };
    final source = _source = _newSource();
    try {
      if (!await source.hasPermission()) {
        _lastStartError = 'Microphone permission is required for speech recognition.';
        await _release();
        return false;
      }
      final stream = await source.start();
      if (session != _session) return false;
      final segmenter = _segmenter = UtteranceSegmenter(onUtterance: (pcm) => _send(session, pcm));
      _audio = stream.listen(segmenter.add, onError: (Object e) => debugPrint('Cloud chunk STT audio error: $e'));
      _listening = true;
      return true;
    } catch (e) {
      _lastStartError = 'The microphone could not be opened for cloud speech recognition: $e';
      await _release();
      return false;
    }
  }

  /// Stops recording, transcribes what was still being said, and waits for
  /// the transcriptions already in flight.
  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    _segmenter?.flush();
    await _release();
    await _queue;
  }

  void _send(int session, Uint8List pcm) {
    final function = _language == 'auto' ? bilingualFunction : singleLanguageFunction;
    _queue = _queue.then((_) async {
      try {
        final data = await _invoke(function, {
          'audioBase64': base64Encode(wav(pcm)),
          'mimeType': 'audio/wav',
          'language': _language,
          'sampleRate': 16000,
          'channels': 1,
        });
        if (data is! Map) return;
        final text = data['transcript']?.toString().trim() ?? '';
        if (text.isEmpty || _results.isClosed) return;
        final detected = (data['detectedLanguage'] ?? data['language'])?.toString();
        _results.add(CloudChunkResult(
          text: text,
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
          language: detected == 'ur' ? 'Urdu' : 'English',
        ));
      } catch (e) {
        if (session == _session) _lastStartError = 'Cloud speech recognition failed: $e';
        debugPrint('Cloud chunk STT request failed: $e');
      }
    });
  }

  /// Wraps 16 kHz mono PCM16 in a WAV header, the format the transcribe
  /// functions default to.
  @visibleForTesting
  static Uint8List wav(Uint8List pcm) {
    final header = ByteData(44);
    void ascii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        header.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 16000 * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return (BytesBuilder(copy: false)
          ..add(header.buffer.asUint8List())
          ..add(pcm))
        .takeBytes();
  }

  Future<void> _release() async {
    await _audio?.cancel();
    _audio = null;
    _segmenter = null;
    final source = _source;
    _source = null;
    await source?.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _results.close();
  }

  static Future<Object?> _invokeSupabase(String function, Map<String, dynamic> body) async {
    final client = SupabaseService.instance.client;
    if (client == null || client.auth.currentSession == null) {
      throw StateError('Authenticated Supabase session is unavailable.');
    }
    final response = await client.functions.invoke(function, body: body).timeout(const Duration(seconds: 20));
    return response.data;
  }
}
