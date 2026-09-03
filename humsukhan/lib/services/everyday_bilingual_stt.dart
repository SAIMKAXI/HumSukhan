import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'everyday_language_policy.dart';
import 'roman_urdu_detector.dart';
import 'supabase_service.dart';

class EverydayBilingualResult {
  final String text;
  final String language;
  final bool isFinal;
  final double confidence;

  const EverydayBilingualResult({
    required this.text,
    required this.language,
    required this.isFinal,
    required this.confidence,
  });
}

class _WordToken {
  final String text;
  final double start;
  final double end;
  final double confidence;
  final String source;

  const _WordToken({
    required this.text,
    required this.start,
    required this.end,
    required this.confidence,
    required this.source,
  });
}

class _TranscriptSegment {
  final List<_WordToken> words;
  final String source;
  final double start;
  final double end;
  final double confidence;

  const _TranscriptSegment({
    required this.words,
    required this.source,
    required this.start,
    required this.end,
    required this.confidence,
  });

  String get text => words.map((word) => word.text).join(' ').trim();
  bool get hasUrdu => EverydayLanguagePolicy.containsUrduScript(text);
  bool get hasLatin => EverydayLanguagePolicy.containsLatin(text);
}

/// Everyday Mode bilingual live recognizer.
///
/// Auto mode keeps English + Urdu recognizers warm over the same PCM stream,
/// but never interleaves their individual words. Each recognizer is segmented
/// by natural pause gaps and overlapping segments are arbitrated as candidates.
/// Explicit English/Urdu modes open only their requested recognizer.
class EverydayBilingualSttService {
  EverydayBilingualSttService._();
  static final EverydayBilingualSttService instance = EverydayBilingualSttService._();

  static const double _segmentGapSeconds = 0.45;
  static const double _overlapToleranceSeconds = 0.10;

  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<EverydayBilingualResult> _controller = StreamController<EverydayBilingualResult>.broadcast();

  WebSocket? _englishSocket;
  WebSocket? _urduSocket;
  StreamSubscription<dynamic>? _englishSubscription;
  StreamSubscription<dynamic>? _urduSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _emitTimer;
  Timer? _finalTimer;

  bool _recording = false;
  bool _ready = false;
  String _mode = 'Auto';
  String? _lastStartError;

  List<_WordToken> _englishWords = const [];
  List<_WordToken> _urduWords = const [];
  String _englishInterim = '';
  String _urduInterim = '';
  double _englishConfidence = 0.0;
  double _urduConfidence = 0.0;
  String _lastEmitted = '';

  Stream<EverydayBilingualResult> get onResult => _controller.stream;
  bool get isListening => _recording;
  bool get isReady => _ready;
  String? get lastStartError => _lastStartError;

  Future<String?> _getTemporaryToken() async {
    final client = SupabaseService.instance.client;
    if (client == null || client.auth.currentSession == null) {
      _lastStartError = 'Authenticated Supabase session is unavailable.';
      return null;
    }
    try {
      final response = await client.functions
          .invoke('deepgram-token')
          .timeout(const Duration(seconds: 5));
      final data = response.data;
      if (data is! Map) {
        _lastStartError = 'Deepgram token service returned an invalid response.';
        return null;
      }
      final token = Map<String, dynamic>.from(data)['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        _lastStartError = 'Deepgram token service returned no access token.';
        return null;
      }
      return token;
    } catch (e) {
      _lastStartError = 'Unable to initialize speech recognition: $e';
      return null;
    }
  }

  Future<WebSocket?> _connect(String language, String token) async {
    final query = <String, String>{
      'model': 'nova-3',
      'language': language,
      'encoding': 'linear16',
      'sample_rate': '16000',
      'channels': '1',
      'interim_results': 'true',
      'smart_format': 'true',
      'punctuate': 'true',
      'endpointing': '350',
      'utterance_end_ms': '1000',
      'vad_events': 'true',
      'words': 'true',
    };
    final uri = Uri.parse('wss://api.deepgram.com/v1/listen').replace(queryParameters: query);
    try {
      return await WebSocket.connect(
        uri.toString(),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));
    } catch (e) {
      _lastStartError = 'Speech recognition connection failed: $e';
      return null;
    }
  }

  Future<bool> start({String mode = 'Auto'}) async {
    if (_recording) return true;
    _mode = _normalizeMode(mode);
    _lastStartError = null;

    final permission = await Permission.microphone.status;
    if (!permission.isGranted) {
      final requested = await Permission.microphone.request();
      if (!requested.isGranted) {
        _lastStartError = requested.isPermanentlyDenied
            ? 'Microphone permission is blocked in Android settings.'
            : 'Microphone permission was not granted.';
        return false;
      }
    }
    if (!await _recorder.hasPermission()) {
      _lastStartError = 'The microphone is not available to the speech recorder.';
      return false;
    }

    final needsEnglish = _mode == 'English' || _mode == 'Auto';
    final needsUrdu = _mode == 'Urdu' || _mode == 'Auto';

    WebSocket? english;
    WebSocket? urdu;

    if (needsEnglish) {
      final token = await _getTemporaryToken();
      if (token == null) return false;
      english = await _connect('en-US', token);
      if (english == null) return false;
    }

    if (needsUrdu) {
      final token = await _getTemporaryToken();
      if (token == null) {
        try { await english?.close(WebSocketStatus.normalClosure, 'Urdu channel unavailable'); } catch (_) {}
        return false;
      }
      urdu = await _connect('ur', token);
      if (urdu == null) {
        try { await english?.close(WebSocketStatus.normalClosure, 'Urdu channel unavailable'); } catch (_) {}
        return false;
      }
    }

    _englishSocket = english;
    _urduSocket = urdu;
    _englishWords = const [];
    _urduWords = const [];
    _englishInterim = '';
    _urduInterim = '';
    _englishConfidence = 0.0;
    _urduConfidence = 0.0;
    _lastEmitted = '';
    _ready = true;

    if (english != null) {
      _englishSubscription = english.listen(
        (message) => _handleSocketMessage('English', message),
        onError: (Object error) => debugPrint('Everyday English STT error: $error'),
        onDone: () {},
      );
    }
    if (urdu != null) {
      _urduSubscription = urdu.listen(
        (message) => _handleSocketMessage('Urdu', message),
        onError: (Object error) => debugPrint('Everyday Urdu STT error: $error'),
        onDone: () {},
      );
    }

    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _recording = true;
      _audioSubscription = stream.listen(
        (data) {
          if (!_recording) return;
          if (_englishSocket?.readyState == WebSocket.open) _englishSocket!.add(data);
          if (_urduSocket?.readyState == WebSocket.open) _urduSocket!.add(data);
        },
        onError: (Object error) {
          _lastStartError = 'Android microphone stream failed: $error';
        },
      );
      return true;
    } catch (e) {
      _lastStartError = 'Failed to start microphone stream: $e';
      await stop();
      return false;
    }
  }

  String _normalizeMode(String mode) {
    switch (mode.toLowerCase().trim()) {
      case 'english':
        return 'English';
      case 'urdu':
      case 'roman urdu':
        return 'Urdu';
      default:
        return 'Auto';
    }
  }

  void _handleSocketMessage(String source, dynamic message) {
    if (message is! String) return;
    try {
      final data = jsonDecode(message);
      if (data is! Map || data['type'] != 'Results') return;
      final channel = data['channel'];
      if (channel is! Map) return;
      final alternatives = channel['alternatives'];
      if (alternatives is! List || alternatives.isEmpty || alternatives.first is! Map) return;
      final alternative = Map<String, dynamic>.from(alternatives.first as Map);
      final rawTranscript = alternative['transcript']?.toString().trim() ?? '';
      if (rawTranscript.isEmpty) return;
      final confidence = (alternative['confidence'] as num?)?.toDouble() ?? 0.0;
      final words = _parseWords(alternative['words'], source);
      final isFinal = data['is_final'] == true;
      final speechFinal = data['speech_final'] == true;

      if (source == 'English') {
        _englishConfidence = confidence;
        _englishInterim = EverydayLanguagePolicy.sanitizeHindi(rawTranscript);
        _englishWords = _replaceRecentWords(_englishWords, words);
      } else {
        _urduConfidence = confidence;
        _urduInterim = EverydayLanguagePolicy.sanitizeHindi(rawTranscript);
        _urduWords = _replaceRecentWords(_urduWords, words);
      }

      if (isFinal || speechFinal) {
        _finalTimer?.cancel();
        _finalTimer = Timer(const Duration(milliseconds: 140), () {
          _emit(complete: speechFinal);
        });
      } else {
        _emitTimer?.cancel();
        _emitTimer = Timer(const Duration(milliseconds: 120), () {
          _emit(complete: false);
        });
      }
    } catch (e) {
      debugPrint('Everyday bilingual STT parse failed: $e');
    }
  }

  List<_WordToken> _parseWords(dynamic rawWords, String source) {
    if (rawWords is! List) return const [];
    final parsed = <_WordToken>[];
    for (final raw in rawWords) {
      if (raw is! Map) continue;
      final punctuated = raw['punctuated_word']?.toString().trim() ?? '';
      final plain = raw['word']?.toString().trim() ?? '';
      final text = punctuated.isNotEmpty ? punctuated : plain;
      if (text.isEmpty || EverydayLanguagePolicy.containsHindiScript(text)) continue;
      final start = (raw['start'] as num?)?.toDouble();
      if (start == null) continue;
      final rawEnd = (raw['end'] as num?)?.toDouble();
      final end = rawEnd == null || rawEnd <= start ? start + 0.18 : rawEnd;
      parsed.add(_WordToken(
        text: text,
        start: start,
        end: end,
        confidence: (raw['confidence'] as num?)?.toDouble() ?? 0.0,
        source: source,
      ));
    }
    return parsed;
  }

  List<_WordToken> _replaceRecentWords(List<_WordToken> old, List<_WordToken> next) {
    if (next.isEmpty) return old;
    final nextStart = next.map((word) => word.start).reduce((a, b) => a < b ? a : b);
    final retained = old.where((word) => word.end < nextStart - 0.05).toList();
    return <_WordToken>[...retained, ...next]..sort((a, b) => a.start.compareTo(b.start));
  }

  List<_TranscriptSegment> _segment(List<_WordToken> words) {
    if (words.isEmpty) return const [];
    final sorted = [...words]..sort((a, b) => a.start.compareTo(b.start));
    final segments = <_TranscriptSegment>[];
    var buffer = <_WordToken>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final previous = buffer.last;
      final current = sorted[i];
      if (current.start - previous.end > _segmentGapSeconds) {
        segments.add(_makeSegment(buffer));
        buffer = <_WordToken>[current];
      } else {
        buffer.add(current);
      }
    }
    segments.add(_makeSegment(buffer));
    return segments;
  }

  _TranscriptSegment _makeSegment(List<_WordToken> words) {
    final confidence = words.isEmpty
        ? 0.0
        : words.map((word) => word.confidence).reduce((a, b) => a + b) / words.length;
    return _TranscriptSegment(
      words: List.unmodifiable(words),
      source: words.first.source,
      start: words.first.start,
      end: words.last.end,
      confidence: confidence,
    );
  }

  bool _overlaps(_TranscriptSegment a, _TranscriptSegment b) {
    return a.start < b.end - _overlapToleranceSeconds && b.start < a.end - _overlapToleranceSeconds;
  }

  double _score(_TranscriptSegment segment) {
    var score = segment.confidence.clamp(0.0, 1.0).toDouble();
    if (_mode == 'English') {
      score += segment.hasLatin ? 0.18 : -0.12;
    } else if (_mode == 'Urdu') {
      score += segment.hasUrdu ? 0.18 : -0.12;
    } else if (segment.hasUrdu && segment.hasLatin) {
      score += 0.08;
    }

    final roman = !segment.hasUrdu && segment.hasLatin && RomanUrduDetector.isRomanUrdu(segment.text);
    if (roman) score += 0.04;
    if (segment.text.length < 2) score -= 0.04;
    return score;
  }

  List<_TranscriptSegment> _arbitrateSegments() {
    final candidates = <_TranscriptSegment>[
      ..._segment(_englishWords),
      ..._segment(_urduWords),
    ]..sort((a, b) {
      final start = a.start.compareTo(b.start);
      return start != 0 ? start : _score(b).compareTo(_score(a));
    });

    final selected = <_TranscriptSegment>[];
    for (final candidate in candidates) {
      final conflicts = selected.where((existing) => _overlaps(existing, candidate)).toList();
      if (conflicts.isEmpty) {
        selected.add(candidate);
        continue;
      }

      final strongestConflict = conflicts.reduce(
        (a, b) => _score(a) >= _score(b) ? a : b,
      );
      if (_score(candidate) <= _score(strongestConflict) + 0.02) continue;

      selected.remove(strongestConflict);
      selected.add(candidate);
    }

    selected.sort((a, b) => a.start.compareTo(b.start));
    return selected;
  }

  String _normalizeSegmentText(String text) {
    var value = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (value.isEmpty) return value;
    if (_mode != 'English' && RomanUrduDetector.isRomanUrdu(value)) {
      value = EverydayLanguagePolicy.normalizeRomanUrdu(value);
    }
    return value.trim();
  }

  String _format({required bool complete}) {
    final segments = _arbitrateSegments();
    if (segments.isEmpty) {
      final candidates = <MapEntry<String, double>>[];
      if (_englishInterim.trim().isNotEmpty) {
        candidates.add(MapEntry(_englishInterim, _englishConfidence));
      }
      if (_urduInterim.trim().isNotEmpty) {
        candidates.add(MapEntry(_urduInterim, _urduConfidence));
      }
      candidates.sort((a, b) => b.value.compareTo(a.value));
      return candidates.isEmpty ? '' : _normalizeSegmentText(candidates.first.key);
    }

    final parts = <String>[];
    for (final segment in segments) {
      final text = _normalizeSegmentText(segment.text);
      if (text.isEmpty) continue;
      final punctuationOnly = RegExp(r'^[,.!?;:%)\]}]+$').hasMatch(text);
      if (parts.isNotEmpty && !punctuationOnly) parts.add(' ');
      parts.add(_mode == 'English' ? EverydayLanguagePolicy.toEnglishMode(text) : text);
    }
    return parts.join().trim();
  }

  void _emit({required bool complete}) {
    if (!_recording && !complete) return;
    final text = _format(complete: complete).trim();
    if (text.isEmpty || text == _lastEmitted) return;
    _lastEmitted = text;

    final hasUrdu = EverydayLanguagePolicy.containsUrduScript(text);
    final hasEnglish = EverydayLanguagePolicy.containsLatin(text);
    final language = hasUrdu && hasEnglish
        ? 'Auto'
        : hasUrdu
            ? 'Urdu'
            : 'English';
    final confidence = (hasUrdu && hasEnglish)
        ? ((_urduConfidence + _englishConfidence) / 2).clamp(0.0, 1.0)
        : hasUrdu
            ? _urduConfidence
            : _englishConfidence;

    _controller.add(EverydayBilingualResult(
      text: EverydayLanguagePolicy.sanitizeHindi(text),
      language: language,
      isFinal: complete,
      confidence: confidence,
    ));

    if (complete) {
      _englishWords = const [];
      _urduWords = const [];
      _englishInterim = '';
      _urduInterim = '';
      _englishConfidence = 0.0;
      _urduConfidence = 0.0;
      _lastEmitted = '';
    }
  }

  Future<void> stop() async {
    _emitTimer?.cancel();
    _finalTimer?.cancel();
    _emitTimer = null;
    _finalTimer = null;

    if (_recording) {
      _recording = false;
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      try { await _recorder.stop(); } catch (_) {}
    }

    for (final socket in [_englishSocket, _urduSocket]) {
      try {
        if (socket?.readyState == WebSocket.open) {
          socket!.add(jsonEncode({'type': 'Finalize'}));
        }
      } catch (_) {}
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _englishSubscription?.cancel();
    await _urduSubscription?.cancel();
    _englishSubscription = null;
    _urduSubscription = null;
    try { await _englishSocket?.close(WebSocketStatus.normalClosure, 'turn ended'); } catch (_) {}
    try { await _urduSocket?.close(WebSocketStatus.normalClosure, 'turn ended'); } catch (_) {}
    _englishSocket = null;
    _urduSocket = null;
    _ready = false;

    _englishWords = const [];
    _urduWords = const [];
    _englishInterim = '';
    _urduInterim = '';
    _lastEmitted = '';
  }

  void dispose() {
    unawaited(stop());
    _controller.close();
    unawaited(_recorder.dispose());
  }
}
