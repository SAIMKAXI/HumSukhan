// Runs the offline speech models the Settings download button fetches,
// with the configuration the app uses. Opt-in: needs the models on disk and
// sherpa-onnx's native library, e.g.
//
//   HUMSUKHAN_OFFLINE_MODELS=/path/with/model/dirs \
//   LD_LIBRARY_PATH=~/.pub-cache/hosted/pub.dev/sherpa_onnx_linux-<version>/linux/x64 \
//   flutter test test/offline_models_real_test.dart
//
// The directories are the models' `modelDir`s from ModelManager, holding the
// files it downloads, plus the `test_wavs/` the model repositories ship.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/stt/model_manager.dart';
import 'package:humsukhan/services/stt/offline_batch_worker.dart';
import 'package:humsukhan/services/stt/vosk_stt.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

final _root = Platform.environment['HUMSUKHAN_OFFLINE_MODELS'];

/// 16 kHz mono PCM16 from a canonical WAV file.
Uint8List _pcm(String path) {
  final bytes = File(path).readAsBytesSync();
  return Uint8List.sublistView(bytes, 44);
}

void main() {
  final english = ModelManager.availableModels['English']!;
  final urdu = ModelManager.availableModels['Urdu']!;

  test('the English streaming model transcribes with the app configuration', () {
    final dir = '$_root/${english.modelDir}';
    sherpa_onnx.initBindings();
    final recognizer = sherpa_onnx.OnlineRecognizer(SherpaSTTProvider.streamingConfig(english, dir));
    final stream = recognizer.createStream();
    final pcm = _pcm('$dir/test_wavs/0.wav');
    final samples = Float32List(pcm.length ~/ 2);
    final view = ByteData.sublistView(pcm);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    stream.acceptWaveform(samples: Float32List(16000), sampleRate: 16000);
    stream.inputFinished();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    final text = recognizer.getResult(stream).text.toLowerCase();
    stream.free();
    recognizer.free();
    expect(text, contains('yellow lamps'));
  }, skip: _root == null ? 'set HUMSUKHAN_OFFLINE_MODELS' : null);

  test('the Urdu model loads on a worker isolate and answers in Urdu script', () async {
    final worker = await OfflineBatchWorker.start(SherpaSTTProvider.whisperFiles(urdu, '$_root/${urdu.modelDir}'));
    addTearDown(worker.dispose);
    final text = await worker.transcribe(_pcm('$_root/${urdu.modelDir}/test_wavs/0.wav'));
    expect(text, isNotEmpty);
    // The clip is English; held to Urdu, Whisper still writes Urdu script.
    expect(RegExp(r'[؀-ۿ]').hasMatch(text), isTrue, reason: text);
  }, skip: _root == null ? 'set HUMSUKHAN_OFFLINE_MODELS' : null, timeout: const Timeout(Duration(minutes: 3)));
}
