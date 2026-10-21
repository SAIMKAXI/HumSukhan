import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/models/monitoring_status.dart';
import 'package:humsukhan/modules/environmental_alerts/services/alert_history_store.dart';
import 'package:humsukhan/providers/environmental_provider.dart';
import 'package:humsukhan/providers/settings_provider.dart';
import 'package:humsukhan/screens/environmental_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMonitor monitor;
  late PermissionStatus permission;
  late List<SoundEvent> flashed;

  EnvironmentalProvider build() => EnvironmentalProvider(
        monitor: monitor,
        requestMicrophone: () async => permission,
        showInAppAlert: (event, _) => flashed.add(event),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    monitor = FakeMonitor();
    permission = PermissionStatus.granted;
    flashed = [];
  });

  group('EnvironmentalProvider', () {
    test('start and stop follow the monitor', () async {
      final provider = build();
      await provider.toggleMonitoring();
      expect(provider.monitoringEnabled, isTrue);
      expect(provider.isProcessing, isTrue);

      await provider.toggleMonitoring();
      expect(provider.monitoringEnabled, isFalse);
      expect(monitor.stopCalls, 1);
    });

    test('a refused microphone is explained and the monitor is not started', () async {
      permission = PermissionStatus.denied;
      final provider = build();
      await provider.toggleMonitoring();
      expect(provider.hasError, isTrue);
      expect(provider.errorMessage, MonitoringFailure.microphoneDenied.message);
      expect(provider.needsSystemSettings, isFalse);
      expect(monitor.startCalls, 0);
    });

    test('a permanently refused microphone points to system settings', () async {
      permission = PermissionStatus.permanentlyDenied;
      final provider = build();
      await provider.toggleMonitoring();
      expect(provider.errorMessage, MonitoringFailure.microphoneBlocked.message);
      expect(provider.needsSystemSettings, isTrue);
    });

    test('a monitor failure is shown with its own message, and clears on a successful retry', () async {
      monitor.startResult = MonitoringStatus.error;
      monitor.startFailure = MonitoringFailure.model;
      final provider = build();
      await provider.toggleMonitoring();
      expect(provider.errorMessage, MonitoringFailure.model.message);

      monitor.startResult = MonitoringStatus.active;
      monitor.startFailure = null;
      await provider.toggleMonitoring();
      expect(provider.hasError, isFalse);
      expect(provider.monitoringEnabled, isTrue);
    });

    test('an alert from the monitor is shown, flashed and picked up from history', () async {
      final provider = build();
      final alert = SoundEvent(id: 'a1', type: 'Siren', severity: 'critical', confidence: 0.9);
      await AlertHistoryStore().append(alert);
      monitor.emit(MonitoringStatus.active, alert: alert);
      await pumpEventQueue();

      expect(provider.currentAlert?.id, 'a1');
      expect(flashed.single.id, 'a1');
      expect(provider.alertHistory.single.id, 'a1');
    });

    test('dismissing a history card dismisses that card, not the alert on the banner', () async {
      final older = SoundEvent(id: 'old', type: 'Knock', timestamp: DateTime(2026, 1, 1));
      final newer = SoundEvent(id: 'new', type: 'Doorbell', timestamp: DateTime(2026, 1, 2));
      await AlertHistoryStore().append(older);
      await AlertHistoryStore().append(newer);
      final provider = build();
      monitor.emit(MonitoringStatus.active, alert: newer);
      await pumpEventQueue();

      await provider.dismissAlert('old');
      expect(provider.currentAlert?.id, 'new');
      expect({for (final e in provider.alertHistory) e.id: e.dismissed}, {'new': false, 'old': true});

      await provider.dismissAlert();
      expect(provider.currentAlert, isNull);
      expect(provider.alertHistory.every((e) => e.dismissed), isTrue);
    });

    test('clear empties history and the banner', () async {
      await AlertHistoryStore().append(SoundEvent(type: 'Knock'));
      final provider = build();
      await pumpEventQueue();
      await provider.clearHistory();
      expect(provider.alertHistory, isEmpty);
      expect(await AlertHistoryStore().load(), isEmpty);
    });

    test('disposing leaves monitoring running', () async {
      final provider = build();
      await provider.toggleMonitoring();
      provider.dispose();
      expect(monitor.stopCalls, 0);
      expect(monitor.status, MonitoringStatus.active);
    });
  });

  group('EnvironmentalScreen', () {
    Future<EnvironmentalProvider> pumpScreen(WidgetTester tester, {Locale locale = const Locale('en')}) async {
      final provider = build();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<EnvironmentalProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const EnvironmentalScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      return provider;
    }

    testWidgets('history lists the newest alert first', (tester) async {
      await tester.runAsync(() async {
        await AlertHistoryStore().append(SoundEvent(type: 'Knock', timestamp: DateTime(2026, 1, 1, 9)));
        await AlertHistoryStore().append(SoundEvent(type: 'Doorbell', timestamp: DateTime(2026, 1, 1, 10)));
      });
      await pumpScreen(tester);
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();

      final doorbell = tester.getTopLeft(find.text('Doorbell'));
      final knock = tester.getTopLeft(find.text('Knock'));
      expect(doorbell.dy, lessThan(knock.dy));
    });

    testWidgets('a blocked microphone offers the system settings button', (tester) async {
      permission = PermissionStatus.permanentlyDenied;
      final provider = await pumpScreen(tester);
      expect(find.text('Open microphone settings'), findsNothing);

      await provider.toggleMonitoring();
      await tester.pumpAndSettle();
      expect(find.text(MonitoringFailure.microphoneBlocked.message), findsOneWidget);
      expect(find.text('Open microphone settings'), findsOneWidget);
    });

    testWidgets('a failure the user cannot fix in settings does not offer the button', (tester) async {
      monitor.startResult = MonitoringStatus.error;
      monitor.startFailure = MonitoringFailure.model;
      final provider = await pumpScreen(tester);
      await provider.toggleMonitoring();
      await tester.pumpAndSettle();
      expect(find.text(MonitoringFailure.model.message), findsOneWidget);
      expect(find.text('Open microphone settings'), findsNothing);
    });

    testWidgets('in Urdu the screen, the failure and its remedy are all Urdu', (tester) async {
      permission = PermissionStatus.permanentlyDenied;
      await tester.runAsync(() => AlertHistoryStore().append(SoundEvent(type: 'Doorbell', timestamp: DateTime(2026, 1, 1, 9))));
      final provider = await pumpScreen(tester, locale: const Locale('ur'));
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();
      expect(find.text('ماحولیاتی نگرانی بند ہے۔'), findsOneWidget);
      expect(find.text('دروازے کی گھنٹی'), findsOneWidget);

      await provider.toggleMonitoring();
      await tester.pumpAndSettle();
      expect(find.text(MonitoringFailure.microphoneBlocked.urduMessage), findsOneWidget);
      expect(find.text('مائیکروفون کی ترتیبات کھولیں'), findsOneWidget);
      expect(find.text(MonitoringFailure.microphoneBlocked.message), findsNothing);
    });
  });
}
