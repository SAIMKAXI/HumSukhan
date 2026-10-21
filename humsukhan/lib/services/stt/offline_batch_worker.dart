import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// Paths and settings for a Whisper model held to one language.
class WhisperModelFiles {
  const WhisperModelFiles({
    required this.encoder,
    required this.decoder,
    required this.tokens,
    required this.language,
  });

  final String encoder;
  final String decoder;
  final String tokens;
  final String language;
}

/// Runs an offline (whole-utterance) recognizer on its own isolate.
///
/// Decoding one sentence with Whisper takes up to a couple of seconds on a
/// phone; done on the UI isolate, the live caption screen would freeze for
/// that long after every sentence. The model is loaded once and kept.
class OfflineBatchWorker {
  OfflineBatchWorker._(this._isolate, this._requests, this._replies);

  final Isolate _isolate;
  final SendPort _requests;
  final ReceivePort _replies;
  final Map<int, Completer<String>> _pending = {};
  int _nextId = 0;

  /// Loads [files] on a new isolate. Throws if the model cannot be loaded.
  static Future<OfflineBatchWorker> start(WhisperModelFiles files) async {
    final replies = ReceivePort();
    final ready = Completer<SendPort>();
    late final OfflineBatchWorker worker;
    replies.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
      } else if (message is String && !ready.isCompleted) {
        ready.completeError(StateError(message));
      } else if (message is List && message.length == 2) {
        worker._pending.remove(message[0])?.complete(message[1] as String);
      }
    });
    final isolate = await Isolate.spawn(_main, (replies.sendPort, files));
    try {
      worker = OfflineBatchWorker._(isolate, await ready.future, replies);
    } catch (_) {
      isolate.kill();
      replies.close();
      rethrow;
    }
    return worker;
  }

  /// Text for one utterance of 16 kHz mono PCM16.
  Future<String> transcribe(Uint8List pcm) {
    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _requests.send((id, TransferableTypedData.fromList([pcm])));
    return completer.future;
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
    _replies.close();
    for (final pending in _pending.values) {
      pending.complete('');
    }
    _pending.clear();
  }

  static void _main((SendPort, WhisperModelFiles) args) {
    final (replies, files) = args;
    final sherpa_onnx.OfflineRecognizer recognizer;
    try {
      sherpa_onnx.initBindings();
      recognizer = sherpa_onnx.OfflineRecognizer(
        sherpa_onnx.OfflineRecognizerConfig(
          model: sherpa_onnx.OfflineModelConfig(
            whisper: sherpa_onnx.OfflineWhisperModelConfig(
              encoder: files.encoder,
              decoder: files.decoder,
              language: files.language,
              task: 'transcribe',
            ),
            tokens: files.tokens,
            numThreads: 2,
          ),
        ),
      );
    } catch (e) {
      replies.send('Offline model could not be loaded: $e');
      return;
    }
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    requests.listen((message) {
      final (id, data) = message as (int, TransferableTypedData);
      final bytes = data.materialize().asUint8List();
      var text = '';
      try {
        final samples = Float32List(bytes.length ~/ 2);
        final view = ByteData.sublistView(bytes);
        for (var i = 0; i < samples.length; i++) {
          samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
        }
        final stream = recognizer.createStream();
        stream.acceptWaveform(samples: samples, sampleRate: 16000);
        recognizer.decode(stream);
        text = recognizer.getResult(stream).text.trim();
        stream.free();
      } catch (_) {
        text = '';
      }
      replies.send([id, text]);
    });
  }
}
