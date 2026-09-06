import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/sound_detection_service.dart';

/// Tests for the environmental acoustic event catalog and service lifecycle.
///
/// These tests validate the supported event pipeline without requiring
/// microphone access or sherpa-ONNX model loading.
void main() {
  group('SoundDetectionService', () {
    test('supportedEvents contains only supported event types', () {
      final events = SoundDetectionService.supportedEvents;

      expect(events, contains('Siren'));
      expect(events, contains('Doorbell'));
      expect(events, contains('Knock'));
      expect(events, isNot(contains('Baby Cry')));
      expect(events, isNot(contains('Phone')));
      expect(events, isNot(contains('Vehicle Horn')));
      expect(events, isNot(contains('Glass Break')));
      expect(events, isNot(contains('Dog Bark')));
      expect(events, isNot(contains('Alarm Clock')));
      expect(events, isNot(contains('Smoke Alarm')));
      expect(events, isNot(contains('Fire Alarm')));
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
      expect(SoundDetectionService.supportedEvents.length, 3);
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

  group('Label Mapping — supported AudioSet labels', () {
    test('Siren maps supported siren labels', () {
      expect(SoundDetectionService.supportedEvents, contains('Siren'));
    });

    test('Doorbell maps doorbell and chime only', () {
      expect(SoundDetectionService.supportedEvents, contains('Doorbell'));
    });

    test('Knock maps knock and tap', () {
      expect(SoundDetectionService.supportedEvents, contains('Knock'));
    });
  });

  group('Label Mapping Coverage', () {
    test('critical events contain only Siren', () {
      expect(SoundDetectionService.supportedEvents, contains('Siren'));
    });

    test('retired events are not available', () {
      final events = SoundDetectionService.supportedEvents;
      expect(events, isNot(contains('Phone')));
      expect(events, isNot(contains('Alarm Clock')));
      expect(events, isNot(contains('Vehicle Horn')));
      expect(events, isNot(contains('Glass Break')));
      expect(events, isNot(contains('Dog Bark')));
      expect(events, isNot(contains('Smoke Alarm')));
      expect(events, isNot(contains('Baby Cry')));
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
