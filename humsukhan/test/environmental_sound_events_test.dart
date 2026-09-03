import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/sound_detection_service.dart';

void main() {
  test('environmental events do not expose microphone-based smoke detection', () {
    expect(SoundDetectionService.supportedEvents, isNot(contains('Fire Alarm')));
    expect(SoundDetectionService.supportedEvents, isNot(contains('Smoke')));
    expect(SoundDetectionService.supportedEvents, contains('Siren'));
  });
}
