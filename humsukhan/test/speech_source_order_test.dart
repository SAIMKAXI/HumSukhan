import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/everyday_bilingual_stt.dart';
import 'package:humsukhan/services/stt/stt_plan.dart';

List<String> plan(String language, {bool online = true, Set<String> device = const {}, Set<String> offline = const {}}) => [
      for (final step in sttPlan(
        language: language,
        online: online,
        deviceHas: device.contains,
        offlineHas: offline.contains,
      ))
        '${step.source.name}:${step.language}',
    ];

/// [ms] of 16 kHz PCM16 at a constant [level].
Uint8List tone(int ms, int level) {
  final data = ByteData(ms * 16 * 2);
  for (var i = 0; i < ms * 16; i++) {
    data.setInt16(i * 2, level, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('speech source order', () {
    test('a language the phone has installed uses the phone first, then the cloud, then offline', () {
      expect(plan('English', device: {'English'}, offline: {'English'}),
          ['device:English', 'cloudStream:English', 'cloudChunk:English', 'offline:English']);
    });

    test('without the phone locale the cloud comes first', () {
      expect(plan('Urdu', device: {'English'}, offline: {'Urdu'}),
          ['cloudStream:Urdu', 'cloudChunk:Urdu', 'offline:Urdu']);
    });

    test('with no connection the cloud is skipped, not waited for', () {
      expect(plan('Urdu', online: false, offline: {'Urdu'}), ['offline:Urdu']);
      expect(plan('English', online: false, device: {'English'}, offline: {'English'}),
          ['device:English', 'offline:English']);
    });

    test('Auto starts with the cloud, the only recognizer that tells English from Urdu', () {
      expect(plan('Auto', device: {'English', 'Urdu'}, offline: {'English'}),
          ['cloudStream:Auto', 'cloudChunk:Auto', 'device:English', 'device:Urdu', 'offline:English']);
    });

    test('Auto offline falls back to whatever the phone or a model can do', () {
      expect(plan('Auto', online: false, offline: {'Urdu'}), ['offline:Urdu']);
    });

    test('nothing available is an empty plan, so the screen can say why', () {
      expect(plan('Urdu', online: false), isEmpty);
    });
  });

  group('caption watchdog', () {
    late List<String> stalls;
    late CaptionWatchdog watchdog;

    setUp(() {
      stalls = [];
      watchdog = CaptionWatchdog(onStall: stalls.add)..reset();
    });

    test('a microphone that sends only zeros is reported', () {
      for (var i = 0; i < 29; i++) {
        watchdog.audio(tone(100, 0));
      }
      expect(stalls, isEmpty);
      watchdog.audio(tone(100, 0));
      expect(stalls.single, contains('microphone is sending silence'));
    });

    test('quiet but real audio is not mistaken for a silenced microphone', () {
      for (var i = 0; i < 100; i++) {
        watchdog.audio(tone(100, 3));
      }
      expect(stalls, isEmpty);
    });

    test('ten seconds of speech with no caption back is reported once', () {
      for (var i = 0; i < 150; i++) {
        watchdog.audio(tone(100, 3000));
      }
      expect(stalls.single, contains('not returning captions'));
    });

    test('captions arriving keep the stream trusted', () {
      for (var i = 0; i < 150; i++) {
        watchdog.audio(tone(100, 3000));
        if (i % 50 == 0) watchdog.captioned();
      }
      expect(stalls, isEmpty);
    });
  });
}
