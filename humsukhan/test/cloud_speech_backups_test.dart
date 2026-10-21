import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/audio/pcm_source.dart';
import 'package:humsukhan/services/cloud_tts_service.dart';
import 'package:humsukhan/services/stt/cloud_chunk_stt.dart';

/// [ms] of 16 kHz PCM16 at a constant [level].
Uint8List tone(int ms, int level) {
  final samples = 16 * ms;
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, level, Endian.little);
  }
  return data.buffer.asUint8List();
}

class FakeMic implements PcmSource {
  final StreamController<Uint8List> audio = StreamController<Uint8List>();
  bool stopped = false;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<Stream<Uint8List>> start() async => audio.stream;
  @override
  Future<void> stop() async => stopped = true;
}

void main() {
  group('UtteranceSegmenter', () {
    late List<Uint8List> utterances;
    late UtteranceSegmenter segmenter;

    setUp(() {
      utterances = [];
      segmenter = UtteranceSegmenter(onUtterance: utterances.add);
    });

    test('an utterance ends after a pause and keeps the audio just before it', () {
      segmenter.add(tone(500, 0));
      segmenter.add(tone(1000, 3000));
      expect(utterances, isEmpty, reason: 'still talking');
      segmenter.add(tone(700, 0));
      expect(utterances, hasLength(1));
      // 300 ms pre-roll + 1000 ms speech + 700 ms of trailing quiet.
      expect(utterances.single.length, tone(2000, 0).length);
    });

    test('a click shorter than the minimum is not sent', () {
      segmenter.add(tone(200, 3000));
      segmenter.add(tone(800, 0));
      expect(utterances, isEmpty);
    });

    test('a long monologue is cut so captions keep coming', () {
      segmenter.add(tone(25000, 3000));
      expect(utterances, hasLength(2));
    });

    test('flush sends speech that was cut off by stopping', () {
      segmenter.add(tone(600, 3000));
      segmenter.flush();
      expect(utterances, hasLength(1));
    });

    test('chunks of any size are reassembled into frames', () {
      final speech = tone(1000, 3000);
      for (var i = 0; i < speech.length; i += 333) {
        segmenter.add(Uint8List.sublistView(speech, i, (i + 333).clamp(0, speech.length)));
      }
      segmenter.add(tone(700, 0));
      expect(utterances, hasLength(1));
    });
  });

  group('CloudChunkStt', () {
    late FakeMic mic;
    late List<(String, Map<String, dynamic>)> calls;
    late CloudChunkStt stt;

    setUp(() {
      mic = FakeMic();
      calls = [];
      stt = CloudChunkStt(
        source: () => mic,
        invoke: (function, body) async {
          calls.add((function, body));
          return {'transcript': 'aap kaise hain', 'detectedLanguage': 'ur', 'confidence': 0.91};
        },
      );
    });

    test('Auto mode sends each utterance to the bilingual function and emits the transcript', () async {
      final results = <CloudChunkResult>[];
      stt.onResult.listen(results.add);
      expect(await stt.start(language: 'Auto'), isTrue);

      mic.audio.add(tone(800, 3000));
      mic.audio.add(tone(700, 0));
      await pumpEventQueue();

      expect(calls.single.$1, CloudChunkStt.bilingualFunction);
      final body = calls.single.$2;
      expect(body['language'], 'auto');
      expect(body['sampleRate'], 16000);
      final sent = base64Decode(body['audioBase64'] as String);
      expect(body['mimeType'], 'audio/wav');
      expect(String.fromCharCodes(sent.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(sent.sublist(8, 12)), 'WAVE');
      expect(ByteData.sublistView(sent).getUint32(24, Endian.little), 16000);
      expect(ByteData.sublistView(sent).getUint32(40, Endian.little), sent.length - 44);
      expect(results.single.text, 'aap kaise hain');
      expect(results.single.language, 'Urdu');
    });

    test('a fixed language uses the single-language function', () async {
      await stt.start(language: 'Urdu');
      mic.audio.add(tone(800, 3000));
      mic.audio.add(tone(700, 0));
      await pumpEventQueue();
      expect(calls.single.$1, CloudChunkStt.singleLanguageFunction);
      expect(calls.single.$2['language'], 'urdu');
    });

    test('stopping mid-sentence still transcribes it and releases the microphone', () async {
      await stt.start(language: 'English');
      mic.audio.add(tone(800, 3000));
      await pumpEventQueue();
      await stt.stop();
      expect(calls, hasLength(1));
      expect(mic.stopped, isTrue);
      expect(stt.isListening, isFalse);
    });

    test('a failed request is reported without stopping the next one', () async {
      var attempt = 0;
      stt = CloudChunkStt(
        source: () => mic,
        invoke: (_, _) async {
          if (attempt++ == 0) throw Exception('timeout');
          return {'transcript': 'second', 'language': 'en'};
        },
      );
      final results = <CloudChunkResult>[];
      stt.onResult.listen(results.add);
      await stt.start(language: 'English');
      mic.audio.add(tone(800, 3000));
      mic.audio.add(tone(700, 0));
      mic.audio.add(tone(800, 3000));
      mic.audio.add(tone(700, 0));
      await pumpEventQueue();
      expect(results.map((r) => r.text), ['second']);
      expect(stt.lastStartError, contains('timeout'));
    });
  });

  group('CloudTtsService', () {
    final audio = {'audioBase64': base64Encode([1, 2, 3]), 'mimeType': 'audio/mpeg', 'provider': 'soniox'};

    test('falls back to speech-synthesis-v2 when the primary fails', () async {
      final tried = <String>[];
      final service = CloudTtsService.withInvoker((function, _) async {
        tried.add(function);
        if (function == 'speech-synthesis') return {'error': 'Soniox TTS failed (502)'};
        return audio;
      });
      final result = await service.synthesize(text: 'سلام', language: 'urdu');
      expect(tried, ['speech-synthesis', 'speech-synthesis-v2']);
      expect(result.audioBytes, [1, 2, 3]);
    });

    test('uses only the primary when it works', () async {
      final tried = <String>[];
      final service = CloudTtsService.withInvoker((function, _) async {
        tried.add(function);
        return audio;
      });
      await service.synthesize(text: 'hello', language: 'english');
      expect(tried, ['speech-synthesis']);
    });

    test('a request the server rejects is not repeated against the backup', () async {
      final tried = <String>[];
      final service = CloudTtsService.withInvoker((function, _) async {
        tried.add(function);
        return {'error': 'Text is required', 'status': 400};
      });
      await expectLater(service.synthesize(text: ' ', language: 'english'), throwsA(isA<CloudTtsException>()));
      expect(tried, ['speech-synthesis']);
    });

    test('when both fail the last failure is reported', () async {
      final service = CloudTtsService.withInvoker((function, _) async => throw Exception('$function down'));
      await expectLater(
        service.synthesize(text: 'hello', language: 'english'),
        throwsA(isA<CloudTtsException>().having((e) => e.message, 'message', contains('speech-synthesis-v2 down'))),
      );
    });
  });
}
