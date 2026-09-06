import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('environmental detector schedules windows without exact callback boundaries', () {
    final source = File('lib/services/sound_detection_service.dart').readAsStringSync();
    expect(source, contains('int _nextProcessSampleCount = _windowSamples;'));
    expect(source, contains('if (_totalSamplesCollected < _windowSamples ||'));
    expect(source, contains('_processWindow();'));
    expect(source, isNot(contains('(_totalSamplesCollected - _windowSamples) % _hopSamples == 0')));
  });

  test('CED classification creates an independent offline stream per window', () {
    final source = File('lib/services/sherpa_audio_tagger.dart').readAsStringSync();
    final classifyStart = source.indexOf('List<SherpaAudioResult> classify');
    final classifyEnd = source.indexOf('Future<List<String>> _loadLabels', classifyStart);
    expect(classifyStart, greaterThanOrEqualTo(0));
    expect(classifyEnd, greaterThan(classifyStart));
    final classifyBody = source.substring(classifyStart, classifyEnd);
    expect(classifyBody, contains('createStream()'));
    expect(classifyBody, contains('stream.free()'));
    expect(classifyBody, contains('acceptWaveform'));
    expect(classifyBody, contains('compute'));
    expect(classifyBody, isNot(contains('_stream!.acceptWaveform')));
  });
}
