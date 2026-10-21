import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/services/alert_history_store.dart';
import 'package:humsukhan/modules/environmental_alerts/services/alert_preferences.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_alert_pipeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

SoundEvent event(String type, {int minute = 0, String? id}) =>
    SoundEvent(id: id, type: type, confidence: 0.9, timestamp: DateTime(2026, 10, 21, 12, minute));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AlertHistoryStore', () {
    test('keeps alerts newest first and survives a reload', () async {
      final store = AlertHistoryStore();
      await store.append(event('Knock', minute: 1));
      await store.append(event('Siren', minute: 2));

      final loaded = await AlertHistoryStore().load();
      expect(loaded.map((e) => e.type), ['Siren', 'Knock']);
    });

    test('keeps at most 100 alerts', () async {
      final store = AlertHistoryStore();
      for (var i = 0; i < 105; i++) {
        await store.append(SoundEvent(type: 'Knock', timestamp: DateTime(2026).add(Duration(minutes: i))));
      }
      final loaded = await store.load();
      expect(loaded, hasLength(AlertHistoryStore.maxEntries));
      expect(loaded.first.timestamp, DateTime(2026).add(const Duration(minutes: 104)));
    });

    test('dismisses only the alert asked for', () async {
      final store = AlertHistoryStore();
      await store.append(event('Knock', id: 'a'));
      await store.append(event('Doorbell', id: 'b', minute: 1));

      final updated = await store.markDismissed('a');
      expect({for (final e in updated) e.id: e.dismissed}, {'a': true, 'b': false});
    });

    test('clear empties history', () async {
      final store = AlertHistoryStore();
      await store.append(event('Knock'));
      expect(await store.clear(), isEmpty);
      expect(await store.load(), isEmpty);
    });

    test('drops sounds that are no longer detected and malformed entries, keeping the rest', () async {
      SharedPreferences.setMockInitialValues({
        AlertHistoryStore.storageKey: jsonEncode([
          event('Baby Cry').toJson(),
          {'type': 'Siren'}, // no timestamp
          event('Siren').toJson(),
        ]),
      });
      final loaded = await AlertHistoryStore().load();
      expect(loaded.map((e) => e.type), ['Siren']);
    });
  });

  group('AlertPreferences', () {
    test('reads what SettingsProvider stores, with its defaults', () async {
      final defaults = await AlertPreferences.read();
      expect(defaults.allows('Siren'), isTrue);
      expect(defaults.hapticAlerts, isTrue);
      expect(defaults.screenFlashAlerts, isTrue);
      expect(defaults.flashAlerts, isFalse);

      SharedPreferences.setMockInitialValues({
        'allowedAlerts': jsonEncode({'Knock': false}),
        'hapticAlerts': false,
        'flashAlerts': true,
      });
      final stored = await AlertPreferences.read();
      expect(stored.allows('Knock'), isFalse);
      expect(stored.allows('Siren'), isTrue);
      expect(stored.hapticAlerts, isFalse);
      expect(stored.flashAlerts, isTrue);
    });
  });

  group('EnvironmentalAlertPipeline', () {
    late List<(SoundEvent, AlertPreferences)> announced;
    late EnvironmentalAlertPipeline pipeline;

    setUp(() {
      announced = [];
      pipeline = EnvironmentalAlertPipeline(announce: (event, prefs) async => announced.add((event, prefs)));
    });

    test('an allowed sound is recorded, then announced with the vibration preference', () async {
      SharedPreferences.setMockInitialValues({'hapticAlerts': false});
      final result = await pipeline.handle(event('Doorbell'));

      expect(result?.type, 'Doorbell');
      expect((await AlertHistoryStore().load()).single.type, 'Doorbell');
      expect(announced.single.$1.type, 'Doorbell');
      expect(announced.single.$2.hapticAlerts, isFalse);
    });

    test('a sound the user switched off is neither recorded nor announced', () async {
      SharedPreferences.setMockInitialValues({'allowedAlerts': jsonEncode({'Knock': false})});
      expect(await pipeline.handle(event('Knock')), isNull);
      expect(await AlertHistoryStore().load(), isEmpty);
      expect(announced, isEmpty);
    });

    test('alerts arriving together are all recorded, in order', () async {
      await Future.wait([
        pipeline.handle(event('Knock', minute: 1)),
        pipeline.handle(event('Doorbell', minute: 2)),
        pipeline.handle(event('Siren', minute: 3)),
      ]);
      expect((await AlertHistoryStore().load()).map((e) => e.type), ['Siren', 'Doorbell', 'Knock']);
      expect(announced.map((a) => a.$1.type), ['Knock', 'Doorbell', 'Siren']);
    });
  });
}
