import 'package:flutter/foundation.dart';

import 'package:record/record.dart';

/// A stream of 16 kHz mono PCM16 from the microphone. Shared by in-app
/// environmental monitoring and the chunked cloud recognizer, and replaced
/// by a fake in tests.
abstract class PcmSource {
  Future<bool> hasPermission();

  /// 16 kHz mono PCM16 little-endian.
  Future<Stream<Uint8List>> start();

  Future<void> stop();
}

class RecorderPcmSource implements PcmSource {
  AudioRecorder? _recorder;

  @override
  Future<bool> hasPermission() => (_recorder ??= AudioRecorder()).hasPermission();

  @override
  Future<Stream<Uint8List>> start() => (_recorder ??= AudioRecorder()).startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

  @override
  Future<void> stop() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    try {
      await recorder.stop();
    } catch (e) {
      debugPrint('Microphone recorder stop failed: $e');
    }
    await recorder.dispose();
  }
}
