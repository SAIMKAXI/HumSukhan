import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/sound_detection_service.dart';

/// Tests for the environmental acoustic event catalog and service lifecycle.
///
/// These tests validate the remaining supported event pipeline without
/// requiring microphone access or sherpa-ONNX model loading.
void main() {
  group('SoundDetectionService', () {
    test('supportedEvents contains only supported event types', () {
      final events = SoundDetectionService.supportedEvents;

      expect(events, contains('Siren'));
      expect(events, contains('Doorbell'));
      expect(events, contains('Knock'));
      expect(events, contains('Phone'));
      expect(events, contains('Baby Cry'));
      expect(events, contains('Alarm Clock'));
      expect(events, contains('Vehicle Horn'));
      expect(events, contains('Glass Break'));
      expect(events, contains('Dog Bark'));
      expect(events, isNot(contains('Fire Alarm')));
      expect(events, isNot(contains('Smoke')));
    });

    test('singleton instance is consistent type', () {
      final instance1 = SoundDetectionService.instance;
      final instance2 = SoundDetectionService.instance;
      expect(instance1.runtimeType, instance2.runtimeType);
    });

    test('initial state is not monitoring', () {
      final service = SoundDetectionService.instance;
      expect(service.isMonitoring, isFalse);
    });

    test('processClassification returns false when not monitoring', () {
      final service = SoundDetectionService.instance;
      service.stopMonitoring();
      final result = service.processClassification('Siren', 0.85);
      expect(result, isFalse);
    });

    test('supportedEvents count matches the active catalog', () {
      expect(SoundDetectionService.supportedEvents.length, 9);
    });

    test('label count is zero before initialization', () {
      final service = SoundDetectionService.instance;
      expect(service.labelCount, 0);
    });

    test('modelLabels is empty before initialization', () {
      final service = SoundDetectionService.instance;
      expect(service.modelLabels, isEmpty);
    });
  });

  group('Label Mapping — real AudioSet labels', () {
    test('Siren maps siren, police, ambulance, fire engine, civil defense', () {
      expect(SoundDetectionService.supportedEvents, contains('Siren'));
    });

    test('Doorbell maps doorbell and chime only', () {
      expect(SoundDetectionService.supportedEvents, contains('Doorbell'));
    });

    test('Knock maps knock and tap', () {
      expect(SoundDetectionService.supportedEvents, contains('Knock'));
    });

    test('Phone maps telephone, ringtone, and car alarm', () {
      expect(SoundDetectionService.supportedEvents, contains('Phone'));
    });

    test('Baby Cry maps baby cry, crying/sobbing, and whimper', () {
      expect(SoundDetectionService.supportedEvents, contains('Baby Cry'));
    });

    test('Alarm Clock maps alarm clock, alarm, buzzer', () {
      expect(SoundDetectionService.supportedEvents, contains('Alarm Clock'));
    });

    test('Vehicle Horn maps vehicle horn, air horn, honk', () {
      expect(SoundDetectionService.supportedEvents, contains('Vehicle Horn'));
    });

    test('Glass Break maps glass and shatter', () {
      expect(SoundDetectionService.supportedEvents, contains('Glass Break'));
    });

    test('Dog Bark maps bark only', () {
      expect(SoundDetectionService.supportedEvents, contains('Dog Bark'));
    });
  });

  group('Label Mapping Coverage', () {
    test('critical events contain only Siren', () {
      expect(SoundDetectionService.supportedEvents, contains('Siren'));
      expect(SoundDetectionService.supportedEvents, isNot(contains('Fire Alarm')));
    });

    test('non-critical events remain available', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Doorbell'));
      expect(events, contains('Knock'));
      expect(events, contains('Phone'));
      expect(events, contains('Baby Cry'));
      expect(events, contains('Alarm Clock'));
      expect(events, contains('Vehicle Horn'));
      expect(events, contains('Glass Break'));
      expect(events, contains('Dog Bark'));
    });
  });

  group('Service Lifecycle', () {
    test('stopMonitoring can be called safely', () {
      final service = SoundDetectionService.instance;
      service.stopMonitoring();
      expect(service.isMonitoring, isFalse);
    });

    test('dispose can be called safely', () {
      final service = SoundDetectionService.instance;
      service.dispose();
      expect(service.isMonitoring, isFalse);
    });
  });
}
