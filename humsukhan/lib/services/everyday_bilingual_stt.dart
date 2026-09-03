import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'everyday_language_policy.dart';
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
  final double confidence;
  final String source;

  const _WordToken({
    required this.text,
    required this.start,
    required this.confidence,
    required this.source,
  });
}

/// Everyday Mode's bilingual live recognizer.
///
/// Nova-3's multilingual `multi` route does not include Urdu, so Everyday
/// Mode uses two explicit recognizers over the same PCM stream: en-US + ur.
/// Their timestamped word streams are merged, with script validation before
/// anything is emitted to the UI. Devanagari is therefore never a valid output.
class EverydayBilingualSttService {
  EverydayBilingualSttService._();
  static final EverydayBilingualSttService instance =
      EverydayBilingualSttService._();

  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<EverydayBilingualResult> _controller =
      StreamController<EverydayBilingualResult>.broadcast();

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
    final uri = Uri.parse('wss://api.deepgram.com/v1/listen')
        .replace(queryParameters: query);
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

    final englishToken = await _getTemporaryToken();
    if (englishToken == null) return false;
    final urduToken = await _getTemporaryToken();
    if (urduToken == null) return false;

    final english = await _connect('en-US', englishToken);
    if (english == null) return false;
    final urdu = await _connect('ur', urduToken);
    if (urdu == null) {
      try {
        await english.close(WebSocketStatus.normalClosure, 'Urdu channel unavailable');
      } catch (_) {}
      return false;
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

    _englishSubscription = english.listen(
      (message) => _handleSocketMessage('English', message),
      onError: (Object error) => debugPrint('Everyday English STT error: $error'),
      onDone: () {},
    );
    _urduSubscription = urdu.listen(
      (message) => _handleSocketMessage('Urdu', message),
      onError: (Object error) => debugPrint('Everyday Urdu STT error: $error'),
      onDone: () {},
    );

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
          if (_englishSocket?.readyState == WebSocket.open) {
            _englishSocket!.add(data);
          }
          if (_urduSocket?.readyState == WebSocket.open) {
            _urduSocket!.add(data);
          }
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
        _englishInterim = _filterTranscript(rawTranscript, keepUrdu: false);
        if (words.isNotEmpty) _englishWords = _mergeSource(_englishWords, words);
      } else {
        _urduConfidence = confidence;
        _urduInterim = _filterTranscript(rawTranscript, keepUrdu: true);
        if (words.isNotEmpty) _urduWords = _mergeSource(_urduWords, words);
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
      if (source == 'Urdu' && !EverydayLanguagePolicy.containsUrduScript(text)) continue;
      if (source == 'English' && !_looksLatin(text)) continue;
      parsed.add(_WordToken(
        text: text,
        start: start,
        confidence: (raw['confidence'] as num?)?.toDouble() ?? 0.0,
        source: source,
      ));
    }
    return parsed;
  }

  bool _looksLatin(String text) {
    if (EverydayLanguagePolicy.containsHindiScript(text)) return false;
    if (EverydayLanguagePolicy.containsUrduScript(text)) return false;
    return RegExp(r'[A-Za-z0-9]').hasMatch(text);
  }

  String _filterTranscript(String text, {required bool keepUrdu}) {
    final cleaned = EverydayLanguagePolicy.sanitizeHindi(text);
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(RegExp(r'\s+'))
        .where((piece) => keepUrdu
            ? EverydayLanguagePolicy.containsUrduScript(piece)
            : _looksLatin(piece))
        .join(' ')
        .trim();
  }

  List<_WordToken> _mergeSource(
    List<_WordToken> old,
    List<_WordToken> next,
  ) {
    final map = <String, _WordToken>{};
    for (final token in old) {
      map['${token.start.toStringAsFixed(3)}|${token.text.toLowerCase()}'] = token;
    }
    for (final token in next) {
      final key = '${token.start.toStringAsFixed(3)}|${token.text.toLowerCase()}';
      final current = map[key];
      if (current == null || token.confidence >= current.confidence) map[key] = token;
    }
    return map.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  List<_WordToken> _mergedWords() {
    final all = <_WordToken>[..._englishWords, ..._urduWords]
      ..removeWhere((word) => EverydayLanguagePolicy.containsHindiScript(word.text));
    all.sort((a, b) => a.start.compareTo(b.start));
    final deduped = <_WordToken>[];
    for (final word in all) {
      final duplicate = deduped.any((existing) =>
          existing.source == word.source &&
          (existing.start - word.start).abs() < 0.09 &&
          existing.text.toLowerCase() == word.text.toLowerCase());
      if (!duplicate) deduped.add(word);
    }
    return deduped;
  }

  String _format({required bool complete}) {
    final words = _mergedWords();
    if (words.isEmpty) {
      final fallback = [_englishInterim, _urduInterim]
          .where((text) => text.trim().isNotEmpty)
          .join(' ');
      return _mode == 'English'
          ? EverydayLanguagePolicy.toEnglishMode(fallback)
          : EverydayLanguagePolicy.withBidiIsolation(fallback);
    }

    final out = StringBuffer();
    for (final word in words) {
      var text = word.text;
      if (_mode == 'English' && word.source == 'Urdu') {
        text = EverydayLanguagePolicy.toEnglishMode(text);
      }
      if (text.isEmpty) continue;
      final punctuationOnly = RegExp(r'^[,.!?;:%)\]}]+$').hasMatch(text);
      if (out.isNotEmpty && !punctuationOnly) out.write(' ');
      if (_mode != 'English' && word.source == 'Urdu') {
        out.write('\u2067$text\u2069');
      } else {
        out.write('\u2066$text\u2069');
      }
    }
    return out.toString().trim();
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
      try {
        await _recorder.stop();
      } catch (_) {}
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
    try {
      await _englishSocket?.close(WebSocketStatus.normalClosure, 'turn ended');
    } catch (_) {}
    try {
      await _urduSocket?.close(WebSocketStatus.normalClosure, 'turn ended');
    } catch (_) {}
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
