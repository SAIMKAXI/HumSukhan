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
        'Phone',
        'Baby Cry',
        'Alarm Clock',
        'Vehicle Horn',
        'Glass Break',
        'Dog Bark',
      ]),
    );
  });
}
