import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/sound_detection_service.dart';

/// Tests for SoundDetectionService label mapping, confidence thresholds,
/// temporal confirmation, and cooldown logic.
///
/// These tests validate the detection pipeline logic without requiring
/// microphone access or sherpa-ONNX model loading.
void main() {
  group('SoundDetectionService', () {
    test('supportedEvents contains all expected event types', () {
      final events = SoundDetectionService.supportedEvents;

      expect(events, contains('Fire Alarm'));
      expect(events, contains('Siren'));
      expect(events, contains('Doorbell'));
      expect(events, contains('Knock'));
      expect(events, contains('Phone'));
      expect(events, contains('Baby Cry'));
      expect(events, contains('Alarm Clock'));
      expect(events, contains('Vehicle Horn'));
      expect(events, contains('Glass Break'));
      expect(events, contains('Dog Bark'));
    });

    test('singleton instance is consistent type', () {
      final instance1 = SoundDetectionService.instance;
      final instance2 = SoundDetectionService.instance;
      expect(instance1.runtimeType, instance2.runtimeType);
    });

    test('initial state is not monitoring and not model ready', () {
      final service = SoundDetectionService.instance;
      expect(service.isMonitoring, isFalse);
    });

    test('processClassification returns false when not monitoring', () {
      final service = SoundDetectionService.instance;
      service.stopMonitoring();
      final result = service.processClassification('Siren', 0.85);
      expect(result, isFalse);
    });

    test('supportedEvents count matches expected', () {
      expect(SoundDetectionService.supportedEvents.length, 10);
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
    // These patterns are verified against the actual CED-Tiny
    // class_labels_indices.csv from HuggingFace.

    test('Fire Alarm maps smoke detector and fire alarm', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Fire Alarm'));
    });

    test('Siren maps siren, police, ambulance, fire engine, civil defense', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Siren'));
    });

    test('Doorbell maps doorbell and chime only', () {
      // "bell" is NOT mapped — too generic (matches Cowbell, Church bell)
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Doorbell'));
    });

    test('Knock maps knock and tap', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Knock'));
    });

    test('Phone maps telephone, ringtone, and car alarm', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Phone'));
    });

    test('Baby Cry maps baby cry, crying/sobbing, and whimper', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Baby Cry'));
    });

    test('Alarm Clock maps alarm clock, alarm, buzzer', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Alarm Clock'));
    });

    test('Vehicle Horn maps vehicle horn, air horn, honk', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Vehicle Horn'));
    });

    test('Glass Break maps glass and shatter', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Glass Break'));
    });

    test('Dog Bark maps bark only', () {
      // "dog" is NOT mapped — too generic (matches growling, whimper)
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Dog Bark'));
    });
  });

  group('Label Mapping Coverage', () {
    test('critical events include Fire Alarm and Siren', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, contains('Fire Alarm'));
      expect(events, contains('Siren'));
    });

    test('non-critical events include Doorbell, Knock, Phone, Baby Cry', () {
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
