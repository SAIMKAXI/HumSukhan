import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/stt/model_manager.dart';

void main() {
  test('offline model sources point to valid Sherpa-ONNX model files', () {
    final english = ModelManager.availableModels['English']!;
    expect(
      english.baseUrl,
      'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/main',
    );
    expect(english.encoder, endsWith('.int8.onnx'));
    expect(english.decoder, endsWith('.int8.onnx'));
    expect(english.joiner, endsWith('.int8.onnx'));
    expect(english.tokens, 'tokens.txt');
    expect(english.isStreaming, isTrue);

    final urdu = ModelManager.availableModels['Urdu']!;
    expect(
      urdu.baseUrl,
      'https://huggingface.co/csukuangfj/sherpa-onnx-dolphin-small-ctc-multi-lang-int8-2025-04-02/resolve/main',
    );
    expect(urdu.modelFile, 'model.int8.onnx');
    expect(urdu.tokens, 'tokens.txt');
    expect(urdu.isStreaming, isFalse);
  });
}
