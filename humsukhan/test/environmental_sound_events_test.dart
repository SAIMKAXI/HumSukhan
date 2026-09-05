import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/sound_detection_service.dart';

void main() {
  test('environmental event catalog contains only supported acoustic alerts', () {
    expect(
      SoundDetectionService.supportedEvents,
      equals([
        'Siren',
        'Doorbell',
        'Knock',
        'Baby Cry',
      ]),
    );
  });

  test('retired environmental alerts are absent from the catalog', () {
    expect(SoundDetectionService.supportedEvents, isNot(contains('Smoke Alarm')));
    expect(SoundDetectionService.supportedEvents, isNot(contains('Phone')));
    expect(SoundDetectionService.supportedEvents, isNot(contains('Vehicle Horn')));
    expect(SoundDetectionService.supportedEvents, isNot(contains('Glass Break')));
    expect(SoundDetectionService.supportedEvents, isNot(contains('Alarm Clock')));
    expect(SoundDetectionService.supportedEvents, isNot(contains('Dog Bark')));
  });
}
