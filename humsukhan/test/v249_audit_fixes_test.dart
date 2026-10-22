import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/models/monitoring_status.dart';
import 'package:humsukhan/modules/environmental_alerts/services/alert_preferences.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_monitor.dart';
import 'package:humsukhan/providers/auth_provider.dart';
import 'package:humsukhan/providers/conversation_provider.dart';
import 'package:humsukhan/providers/environmental_provider.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/providers/professional_provider.dart';
import 'package:humsukhan/providers/quick_reply_provider.dart';
import 'package:humsukhan/providers/settings_provider.dart';
import 'package:humsukhan/providers/user_provider.dart';
import 'package:humsukhan/screens/professional_screen.dart';
import 'package:humsukhan/screens/settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'environmental/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers', 'flutter_tts']) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Visual alerts switch', () {
    test('is read by the detection pipeline', () async {
      SharedPreferences.setMockInitialValues({'visualAlerts': false});
      expect((await AlertPreferences.read()).visualAlerts, isFalse);
      SharedPreferences.setMockInitialValues({});
      expect((await AlertPreferences.read()).visualAlerts, isTrue);
    });

    test('off: the alert is kept in history but no banner covers the screen', () async {
      SharedPreferences.setMockInitialValues({'visualAlerts': false});
      final settings = SettingsProvider();
      await pumpEventQueue();
      final monitor = FakeMonitor();
      final flashed = <SoundEvent>[];
      final provider = EnvironmentalProvider(
        monitor: monitor,
        requestMicrophone: () async => PermissionStatus.granted,
        showInAppAlert: (event, _) => flashed.add(event),
      )..setSettingsProvider(settings);
      monitor.emit(MonitoringStatus.active, alert: SoundEvent(type: 'Siren', severity: 'critical'));
      await pumpEventQueue();
      expect(provider.currentAlert, isNull);
      expect(flashed, hasLength(1), reason: 'screen flash and torch have their own switches');
    });
  });

  group('Environmental monitoring and captions', () {
    late FakeMonitor monitor;
    setUp(() {
      monitor = FakeMonitor();
      EnvironmentalMonitoring.instance = monitor;
    });

    test('monitoring stopped to free the microphone starts again afterwards', () async {
      await monitor.start();
      expect(await EnvironmentalMonitoring.releaseForForegroundSpeech(), isTrue);
      expect(monitor.status, MonitoringStatus.off);

      await EnvironmentalMonitoring.resumeAfterForegroundSpeech();
      expect(monitor.status, MonitoringStatus.active);
      expect(monitor.startCalls, 2);
    });

    test('monitoring that was off stays off', () async {
      await EnvironmentalMonitoring.releaseForForegroundSpeech();
      await EnvironmentalMonitoring.resumeAfterForegroundSpeech();
      expect(monitor.startCalls, 0);
    });

    test('it is resumed once, not every time captions stop', () async {
      await monitor.start();
      await EnvironmentalMonitoring.releaseForForegroundSpeech();
      await EnvironmentalMonitoring.resumeAfterForegroundSpeech();
      await monitor.stop();
      await EnvironmentalMonitoring.resumeAfterForegroundSpeech();
      expect(monitor.status, MonitoringStatus.off, reason: 'the user turned it off after it was resumed');
    });
  });

  test('a conversation discarded while its screen closes does not notify', () {
    final conversation = ConversationProvider();
    var notified = 0;
    conversation.addListener(() => notified++);
    conversation.deleteConversation(notify: false);
    expect(notified, 0);
    conversation.deleteConversation();
    expect(notified, 1);
  });

  group('Professional folders', () {
    Future<ProfessionalProvider> pumpProfessional(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'professionalFolders:guest': jsonEncode([Folder(name: 'Work').toJson()]),
      });
      final pro = ProfessionalProvider();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfessionalProvider>.value(value: pro),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MaterialApp(localizationsDelegates: [AppStrings.delegate], home: ProfessionalScreen()),
      ));
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();
      return pro;
    }

    testWidgets('another folder can be created once one exists', (tester) async {
      final pro = await pumpProfessional(tester);
      expect(find.text('Work'), findsOneWidget);
      await tester.tap(find.text('Create Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Lectures 2026');
      await tester.tap(find.text('Create'));
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();
      expect(pro.folders.map((f) => f.name), ['Work', 'Lectures 2026']);
    });

    testWidgets('a duplicate name is explained and the dialog stays open', (tester) async {
      final pro = await pumpProfessional(tester);
      await tester.tap(find.text('Create Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'work');
      await tester.tap(find.text('Create'));
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('A folder with this name already exists'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(pro.folders, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('Profile editing', () {
    Future<UserProvider> pumpSettings(WidgetTester tester) async {
      final user = UserProvider();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<SpeechProvider>(create: (_) => SpeechProvider()),
          ChangeNotifierProvider(create: (_) => QuickReplyProvider()),
        ],
        child: const MaterialApp(localizationsDelegates: [AppStrings.delegate], home: SettingsScreen()),
      ));
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();
      return user;
    }

    testWidgets('the name is saved and the sheet closes cleanly', (tester) async {
      final user = await pumpSettings(tester);
      await tester.tap(find.text('Set up profile').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ayesha');
      await tester.tap(find.text('Save'));
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();
      expect(user.profile?.name, 'Ayesha');
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull, reason: 'the text controller must outlive the closing sheet');
    });

    testWidgets('an empty name is explained instead of ignored', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Set up profile').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Please enter your name.'), findsOneWidget);
    });
  });
}
