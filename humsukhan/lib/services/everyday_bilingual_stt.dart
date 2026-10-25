import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

/// Notices a recognizer that is open but captioning nothing.
///
/// A socket can stay open while nothing useful comes back: the microphone
/// delivers only zeros because something else holds it, or the service
/// accepts audio and returns no words. Either way the screen would show
/// "listening" and never caption anything. [onStall] fires once per [reset].
class CaptionWatchdog {
  CaptionWatchdog({
    required this.onStall,
    this.silentMicrophoneLimit = const Duration(seconds: 3),
    this.speechWithoutCaptionLimit = const Duration(seconds: 10),
    this.speechRms = 0.03,
  });

  final void Function(String reason) onStall;
  final Duration silentMicrophoneLimit;
  final Duration speechWithoutCaptionLimit;
  final double speechRms;

  int _silentMs = 0;
  int _speechWithoutCaptionMs = 0;
  bool _heardAnything = false;
  bool _stalled = false;

  void reset() {
    _silentMs = 0;
    _speechWithoutCaptionMs = 0;
    _heardAnything = false;
    _stalled = false;
  }

  /// Words came back.
  void captioned() => _speechWithoutCaptionMs = 0;

  /// One chunk of the 16 kHz PCM16 sent to the recognizer.
  void audio(Uint8List pcm) {
    final samples = pcm.length ~/ 2;
    if (_stalled || samples == 0) return;
    final ms = samples ~/ 16;
    final view = ByteData.sublistView(pcm);
    var loud = false;
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final v = view.getInt16(i * 2, Endian.little);
      if (v != 0) loud = true;
      sum += (v / 32768) * (v / 32768);
    }
    if (loud) _heardAnything = true;
    if (!_heardAnything) {
      _silentMs += ms;
      if (_silentMs >= silentMicrophoneLimit.inMilliseconds) {
        _stall('The microphone is sending silence, so nothing can be captioned. '
            'Another app or feature may be using it.');
      }
      return;
    }
    if (math.sqrt(sum / samples) >= speechRms) {
      _speechWithoutCaptionMs += ms;
      if (_speechWithoutCaptionMs >= speechWithoutCaptionLimit.inMilliseconds) {
        _stall('The cloud recognizer is not returning captions.');
      }
    }
  }

  void _stall(String reason) {
    _stalled = true;
    onStall(reason);
  }
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
  final StreamController<String> _connectionLost = StreamController<String>.broadcast();
  final StreamController<void> _voiceStarted = StreamController<void>.broadcast();

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

  // Every start()/stop() advances the session generation. Each socket also has
  // independent reconnect state so a failure on one recognizer never blocks or
  // consumes the retry budget of the other recognizer.
  int _sessionGeneration = 0;
  final Set<String> _reconnectingSources = <String>{};
  final Map<String, int> _reconnectAttempts = <String, int>{};

  static const int _maxReconnectAttempts = 3;

  late final CaptionWatchdog _watchdog = CaptionWatchdog(onStall: (reason) {
    _lastStartError = reason;
    debugPrint('Everyday STT stalled: $reason');
    _connectionLost.add(reason);
  });

  List<_WordToken> _englishWords = const [];
  List<_WordToken> _urduWords = const [];
  String _englishInterim = '';
  String _urduInterim = '';
  double _englishConfidence = 0.0;
  double _urduConfidence = 0.0;
  String _lastEmitted = '';

  /// Audio time, in seconds, up to which speech has been emitted as a
  /// finished utterance. Both recognizers hear the same audio, and the
  /// slower one's copy of a finished utterance must not be captioned again.
  double _completedUntil = 0;

  Stream<EverydayBilingualResult> get onResult => _controller.stream;

  /// Fires, with the reason, when reconnecting has failed and no recognizer
  /// socket is left open: the microphone is still recording but nothing can
  /// turn it into captions any more.
  Stream<String> get onConnectionLost => _connectionLost.stream;

  /// Deepgram heard someone start speaking, before any words come back.
  /// Lets a pause be told from the end of a sentence by sound, not only by
  /// words.
  Stream<void> get onVoiceStarted => _voiceStarted.stream;
  bool get isListening => _recording;
  bool get isReady => _ready;
  String? get lastStartError => _lastStartError;

  // Deepgram tokens from `deepgram-token` last an hour. One is kept and
  // shared by both recognizers, so starting the microphone does not wait on
  // the edge function every time.
  String? _token;
  DateTime _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(0);
  Future<String?>? _tokenRequest;
  static const Duration _tokenMargin = Duration(minutes: 2);

  /// Fetches a token ahead of the first start, so the first tap on the
  /// microphone only has to connect.
  Future<void> prewarm() async {
    await _getTemporaryToken();
  }

  @visibleForTesting
  void debugForgetToken() => _forgetToken();

  void _forgetToken() {
    _token = null;
    _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<String?> _getTemporaryToken() {
    final cached = _token;
    if (cached != null && DateTime.now().isBefore(_tokenExpiry)) return Future.value(cached);
    return _tokenRequest ??= _requestToken().whenComplete(() => _tokenRequest = null);
  }

  /// Replaces the `deepgram-token` call in tests.
  @visibleForTesting
  Future<({String token, Duration lifetime})?> Function()? debugTokenSource;

  Future<String?> _requestToken() async {
    final source = debugTokenSource;
    if (source != null) {
      final issued = await source();
      if (issued == null) return null;
      _token = issued.token;
      _tokenExpiry = DateTime.now().add(issued.lifetime - _tokenMargin);
      return issued.token;
    }
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
      final body = Map<String, dynamic>.from(data);
      final token = body['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        _lastStartError = 'Deepgram token service returned no access token.';
        return null;
      }
      final lifetime = Duration(seconds: (body['expiresIn'] as num?)?.toInt() ?? 0);
      _token = token;
      _tokenExpiry = DateTime.now().add(lifetime - _tokenMargin);
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
      // Long enough that a breath inside a sentence does not end it, so the
      // recognizer finalizes words with the rest of their sentence in view.
      'endpointing': '500',
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
      // The token may be what was refused; fetch a fresh one next time.
      _forgetToken();
      _lastStartError = 'Speech recognition connection failed: $e';
      return null;
    }
  }

  Future<bool> start({String mode = 'Auto'}) async {
    if (_recording) return true;
    final generation = ++_sessionGeneration;
    _mode = _normalizeMode(mode);
    _lastStartError = null;
    _reconnectingSources.clear();
    _reconnectAttempts.clear();

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
    if (generation != _sessionGeneration) return false;
    if (!await _recorder.hasPermission()) {
      _lastStartError = 'The microphone is not available to the speech recorder.';
      return false;
    }
    if (generation != _sessionGeneration) return false;

    final needsEnglish = _mode == 'English' || _mode == 'Auto';
    final needsUrdu = _mode == 'Urdu' || _mode == 'Auto';

    // The microphone opens while the recognizers connect, and what is said
    // meanwhile is kept and sent once they are open. Both recognizers
    // connect at the same time, with one token.
    final microphone = _openMicrophone(generation);
    final token = await _getTemporaryToken();
    final connections = token == null
        ? const <WebSocket?>[]
        : await Future.wait([
            needsEnglish ? _connect('en-US', token) : Future<WebSocket?>.value(),
            needsUrdu ? _connect('ur', token) : Future<WebSocket?>.value(),
          ]);
    final micOpen = await microphone;
    final english = connections.isEmpty ? null : connections[0];
    final urdu = connections.isEmpty ? null : connections[1];
    final connected = token != null && (!needsEnglish || english != null) && (!needsUrdu || urdu != null);

    if (!connected || !micOpen || generation != _sessionGeneration) {
      for (final socket in [english, urdu]) {
        if (socket != null) unawaited(_close(socket, 'superseded'));
      }
      if (generation == _sessionGeneration) await _closeMicrophone();
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
    _completedUntil = 0;
    _ready = true;

    if (english != null) _listenToSocket('English', english, generation);
    if (urdu != null) _listenToSocket('Urdu', urdu, generation);

    _recording = true;
    _watchdog.reset();
    final early = List<Uint8List>.of(_earlyAudio);
    _earlyAudio.clear();
    _earlyAudioBytes = 0;
    early.forEach(_sendAudio);
    return true;
  }

  /// Audio recorded before the recognizers were open, at most
  /// [_earlyAudioLimit] bytes (3 s of 16 kHz PCM16).
  final List<Uint8List> _earlyAudio = <Uint8List>[];
  int _earlyAudioBytes = 0;
  static const int _earlyAudioLimit = 16000 * 2 * 3;

  /// 16 kHz mono PCM from the source Android tunes for speech recognition:
  /// no automatic gain or noise processing that smears consonants, which
  /// costs recognizers more accuracy than the noise they remove.
  static const RecordConfig recognitionAudio = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
    androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
  );

  Future<bool> _openMicrophone(int generation) async {
    _earlyAudio.clear();
    _earlyAudioBytes = 0;
    try {
      final stream = await _recorder.startStream(recognitionAudio);
      if (generation != _sessionGeneration) {
        try { await _recorder.stop(); } catch (_) {}
        return false;
      }
      _audioSubscription = stream.listen(
        (data) {
          if (generation != _sessionGeneration) return;
          if (_recording) {
            _sendAudio(data);
          } else if (_earlyAudioBytes < _earlyAudioLimit) {
            _earlyAudio.add(data);
            _earlyAudioBytes += data.length;
          }
        },
        onError: (Object error) {
          _lastStartError = 'Android microphone stream failed: $error';
        },
      );
      return true;
    } catch (e) {
      _lastStartError = 'Failed to start microphone stream: $e';
      return false;
    }
  }

  void _sendAudio(Uint8List data) {
    if (_englishSocket?.readyState == WebSocket.open) _englishSocket!.add(data);
    if (_urduSocket?.readyState == WebSocket.open) _urduSocket!.add(data);
    _watchdog.audio(data);
  }

  Future<void> _closeMicrophone() async {
    _earlyAudio.clear();
    _earlyAudioBytes = 0;
    final subscription = _audioSubscription;
    _audioSubscription = null;
    if (subscription == null) return;
    await subscription.cancel();
    try { await _recorder.stop(); } catch (_) {}
  }

  static Future<void> _close(WebSocket socket, String reason) async {
    try { await socket.close(WebSocketStatus.normalClosure, reason); } catch (_) {}
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

  /// Starts arbitrating [mode] without a microphone or sockets, so tests can
  /// feed recognizer messages to [debugReceive].
  @visibleForTesting
  void debugBegin(String mode) {
    _mode = _normalizeMode(mode);
    _recording = true;
    _englishWords = const [];
    _urduWords = const [];
    _englishInterim = '';
    _urduInterim = '';
    _lastEmitted = '';
    _completedUntil = 0;
  }

  @visibleForTesting
  void debugReceive(String source, String message) => _handleSocketMessage(source, message);

  void _listenToSocket(String source, WebSocket socket, int generation) {
    final subscription = socket.listen(
      (message) => _handleSocketMessage(source, message),
      onError: (Object error) => debugPrint('Everyday $source STT error: $error'),
      onDone: () => _handleSocketClosed(source, generation),
    );
    if (source == 'English') {
      _englishSubscription = subscription;
    } else {
      _urduSubscription = subscription;
    }
  }

  void _handleSocketClosed(String source, int generation) {
    if (!_recording || generation != _sessionGeneration) return;
    debugPrint('Everyday $source STT socket closed mid-session; reconnecting');
    unawaited(_reconnectSocket(source, generation));
  }

  /// Re-opens only the recognizer socket that dropped. English and Urdu keep
  /// independent retry ownership and budgets, so a failure in one channel
  /// cannot suppress recovery of the other.
  Future<void> _reconnectSocket(String source, int generation) async {
    if (!_recording || generation != _sessionGeneration) return;
    if (_reconnectingSources.contains(source)) return;
    _reconnectingSources.add(source);
    try {
      while (_recording && generation == _sessionGeneration) {
        final attempts = _reconnectAttempts[source] ?? 0;
        if (attempts >= _maxReconnectAttempts) break;
        _reconnectAttempts[source] = attempts + 1;

        await Future<void>.delayed(
          Duration(milliseconds: 400 * (attempts + 1)),
        );
        if (!_recording || generation != _sessionGeneration) return;

        final token = await _getTemporaryToken();
        if (token == null) continue;
        if (!_recording || generation != _sessionGeneration) return;

        final socket = await _connect(source == 'English' ? 'en-US' : 'ur', token);
        if (socket == null) continue;
        if (!_recording || generation != _sessionGeneration) {
          try {
            await socket.close(WebSocketStatus.normalClosure, 'superseded');
          } catch (_) {}
          return;
        }

        if (source == 'English') {
          await _englishSubscription?.cancel();
          _englishSocket = socket;
        } else {
          await _urduSubscription?.cancel();
          _urduSocket = socket;
        }
        _listenToSocket(source, socket, generation);
        // A new socket counts audio time from zero.
        _completedUntil = 0;
        _reconnectAttempts[source] = 0;
        if (_recording && generation == _sessionGeneration) {
          _lastStartError = null;
        }
        return;
      }

      if (_recording && generation == _sessionGeneration) {
        _lastStartError =
            'Speech recognition lost its $source connection and could not reconnect. '
            'Check your internet connection, then start listening again.';
        final anyOpen = [_englishSocket, _urduSocket]
            .any((socket) => socket != null && socket.readyState == WebSocket.open);
        if (!anyOpen) _connectionLost.add(_lastStartError!);
      }
    } finally {
      _reconnectingSources.remove(source);
    }
  }

  void _handleSocketMessage(String source, dynamic message) {
    if (message is! String) return;
    try {
      final data = jsonDecode(message);
      if (data is! Map) return;
      switch (data['type']) {
        case 'SpeechStarted':
          if (_recording) _voiceStarted.add(null);
          return;
        case 'UtteranceEnd':
          // Sent after a second with no words, even when noise kept the
          // recognizer from marking the end of speech.
          if (_englishInterim.isNotEmpty || _urduInterim.isNotEmpty) {
            _finalTimer?.cancel();
            _finalTimer = Timer(const Duration(milliseconds: 140), () => _emit(complete: true));
          }
          return;
        case 'Results':
          break;
        default:
          return;
      }
      if (data['from_finalize'] == true) _finalizeAnswered();
      final channel = data['channel'];
      if (channel is! Map) return;
      final alternatives = channel['alternatives'];
      if (alternatives is! List || alternatives.isEmpty || alternatives.first is! Map) return;
      final alternative = Map<String, dynamic>.from(alternatives.first as Map);
      final rawTranscript = alternative['transcript']?.toString().trim() ?? '';
      if (rawTranscript.isEmpty) return;
      _watchdog.captioned();
      final confidence = (alternative['confidence'] as num?)?.toDouble() ?? 0.0;
      final parsed = _parseWords(alternative['words'], source);
      final words = parsed.where((word) => word.end > _completedUntil + 0.02).toList();
      if (parsed.isNotEmpty && words.isEmpty) return;
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
        _emitTimer = Timer(const Duration(milliseconds: 50), () {
          _emit(complete: false);
        });
      }
    } catch (e) {
      debugPrint('Everyday bilingual STT parse failed: $e');
    }
  }

  void _finalizeAnswered() {
    final finalized = _finalized;
    if (finalized == null || finalized.isCompleted) return;
    if (--_finalizePending <= 0) finalized.complete();
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

  /// In Auto, the English recognizer writes Urdu speech out phonetically.
  /// Roman Urdu from it is the clearest sign that Urdu was spoken, so the
  /// Urdu recognizer's transcript of the same words is the one to show.
  bool _englishHeardUrdu = false;

  /// Function words found in nearly every Urdu sentence. Urdu speech
  /// recognized as Urdu is full of them; English speech written out in Urdu
  /// letters by the Urdu recognizer has almost none.
  static const Set<String> _urduFunctionWords = {
    'ہے', 'ہیں', 'تھا', 'تھی', 'تھے', 'ہو', 'ہوں', 'گا', 'گی', 'گے', 'کے', 'کی',
    'کا', 'کو', 'سے', 'میں', 'نے', 'پر', 'اور', 'یہ', 'وہ', 'نہیں', 'نہ', 'کیا',
    'کہ', 'تو', 'بھی', 'ہی', 'جو', 'اس', 'ان', 'آپ', 'ہم', 'مجھے', 'تم', 'رہا',
    'رہی', 'رہے', 'گیا', 'کر', 'کچھ', 'بہت', 'اب', 'جی', 'ہاں', 'لیکن', 'اگر',
  };

  /// The English equivalent, for English speech recognized as English.
  static const Set<String> _englishFunctionWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'to', 'of', 'and', 'in', 'on',
    'it', 'you', 'i', 'we', 'they', 'that', 'this', 'for', 'with', 'have', 'has',
    'do', 'does', 'not', 'be', 'will', 'can', 'my', 'your', 'what', 'how', 'at',
  };

  static ({int hits, double share}) _functionWords(_TranscriptSegment segment, Set<String> functionWords) {
    final words = segment.words
        .map((w) => w.text.toLowerCase().replaceAll(RegExp(r'''[.?!۔؟,،;:"']'''), '').replaceAll('ي', 'ی').replaceAll('ك', 'ک'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return (hits: 0, share: 0);
    final hits = words.where(functionWords.contains).length;
    return (hits: hits, share: hits / words.length);
  }

  /// How much a segment reads like real speech in its recognizer's
  /// language. Short segments say too little to judge.
  ///
  /// Only the absence of function words counts against English: Urdu
  /// misheard as English is still full of "a", "are" and "the".
  double _plausibility(_TranscriptSegment segment) {
    if (_mode != 'Auto' || segment.words.length < 3) return 0;
    if (segment.source == 'Urdu') {
      final found = _functionWords(segment, _urduFunctionWords);
      if (found.hits >= 2 && found.share >= 0.25) return 0.12;
      if (found.hits == 0) return -0.15;
      return 0;
    }
    return _functionWords(segment, _englishFunctionWords).hits == 0 ? -0.08 : 0;
  }

  /// A speaker rarely switches language for a moment and back: within one
  /// utterance the language of the part before tips a close call.
  static const double _continuity = 0.05;

  double _score(_TranscriptSegment segment, {String? previousSource}) {
    var score = segment.confidence.clamp(0.0, 1.0).toDouble() + _plausibility(segment);
    if (previousSource != null && segment.source == previousSource) score += _continuity;
    if (_mode == 'English') {
      score += segment.hasLatin ? 0.18 : -0.12;
    } else if (_mode == 'Urdu') {
      score += segment.hasUrdu ? 0.18 : -0.12;
    } else if (_englishHeardUrdu) {
      score += segment.source == 'Urdu' ? 0.15 : -0.15;
    } else if (segment.hasUrdu && segment.hasLatin) {
      score += 0.08;
    }
    final roman = !segment.hasUrdu && segment.hasLatin && RomanUrduDetector.isRomanUrdu(segment.text);
    if (roman && _mode != 'Auto') score += 0.04;
    if (segment.text.length < 2) score -= 0.04;
    return score;
  }

  List<_TranscriptSegment> _arbitrateSegments() {
    final english = _segment(_englishWords);
    final urdu = _segment(_urduWords);
    _englishHeardUrdu = _mode == 'Auto' &&
        urdu.isNotEmpty &&
        RomanUrduDetector.isRomanUrdu(english.map((segment) => segment.text).join(' '));
    final candidates = <_TranscriptSegment>[
      ...english,
      ...urdu,
    ]..sort((a, b) {
      final start = a.start.compareTo(b.start);
      return start != 0 ? start : _score(b).compareTo(_score(a));
    });

    final selected = <_TranscriptSegment>[];
    for (final candidate in candidates) {
      final conflicts = selected.where((existing) => _overlaps(existing, candidate)).toList();
      final before = selected.where((existing) => existing.end <= candidate.start + _overlapToleranceSeconds).toList();
      final previousSource = before.isEmpty ? null : before.reduce((a, b) => a.end >= b.end ? a : b).source;
      if (conflicts.isEmpty) {
        selected.add(candidate);
        continue;
      }

      final strongestConflict = conflicts.reduce(
        (a, b) => _score(a, previousSource: previousSource) >= _score(b, previousSource: previousSource) ? a : b,
      );
      if (_score(candidate, previousSource: previousSource) <=
          _score(strongestConflict, previousSource: previousSource) + 0.02) {
        continue;
      }

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
      for (final word in [..._englishWords, ..._urduWords]) {
        if (word.end > _completedUntil) _completedUntil = word.end;
      }
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
    ++_sessionGeneration;
    _emitTimer?.cancel();
    _finalTimer?.cancel();
    _emitTimer = null;
    _finalTimer = null;
    _reconnectingSources.clear();
    _reconnectAttempts.clear();

    final hadPendingWords = _englishInterim.isNotEmpty || _urduInterim.isNotEmpty;
    _recording = false;
    await _closeMicrophone();

    final sockets = [_englishSocket, _urduSocket].whereType<WebSocket>().toList();
    final open = sockets.where((socket) => socket.readyState == WebSocket.open).toList();
    if (hadPendingWords && open.isNotEmpty) {
      // Ask for the words the recognizers still hold, waiting only until
      // each has answered, and never longer than [_finalizeWait].
      _finalizePending = open.length;
      _finalized = Completer<void>();
      for (final socket in open) {
        try { socket.add(jsonEncode({'type': 'Finalize'})); } catch (_) {}
      }
      await _finalized!.future.timeout(_finalizeWait, onTimeout: () {});
      _finalized = null;
    }

    await _englishSubscription?.cancel();
    await _urduSubscription?.cancel();
    _englishSubscription = null;
    _urduSubscription = null;
    // Closing waits for Deepgram's reply; nothing here needs it.
    for (final socket in sockets) {
      if (socket.readyState == WebSocket.open) {
        try { socket.add(jsonEncode({'type': 'CloseStream'})); } catch (_) {}
      }
      unawaited(_close(socket, 'turn ended'));
    }
    _englishSocket = null;
    _urduSocket = null;
    _ready = false;

    _englishWords = const [];
    _urduWords = const [];
    _englishInterim = '';
    _urduInterim = '';
    _lastEmitted = '';
  }

  static const Duration _finalizeWait = Duration(milliseconds: 300);
  Completer<void>? _finalized;
  int _finalizePending = 0;

  void dispose() {
    unawaited(stop());
    _controller.close();
    _voiceStarted.close();
    unawaited(_recorder.dispose());
  }
}