import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/providers/auth_provider.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/providers/quick_reply_provider.dart';
import 'package:humsukhan/providers/settings_provider.dart';
import 'package:humsukhan/providers/user_provider.dart';
import 'package:humsukhan/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every control in Settings responds, is stored, and opens and closes its
/// dialog without an error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers', 'flutter_tts']) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }

  late SettingsProvider settings;


  Future<void> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsProvider();
    // Tall enough that the whole list is built and on screen.
    tester.view.physicalSize = const Size(1080, 15000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<SpeechProvider>(create: (_) => SpeechProvider()),
        ChangeNotifierProvider(create: (_) => QuickReplyProvider()),
      ],
      child: const MaterialApp(localizationsDelegates: [AppStrings.delegate], home: SettingsScreen()),
    ));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
  }

  /// Unmounts the screen and lets the speech provider's shutdown finish.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// The audio player's event streams have no platform side in tests.
  void ignoreAudioPlugin() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException && '${details.exception}'.contains('audioplayers')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    // The last match: a section header can repeat a tile's title.
    await tester.tap(find.text(text).last);
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
  }

  testWidgets('every switch flips its setting and stores it', (tester) async {
    ignoreAudioPlugin();
    await pumpSettings(tester);
    final switches = <String, bool Function()>{
      'Dark Mode': () => settings.isDarkMode,
      'High Contrast': () => settings.isHighContrast,
      'Large Text': () => settings.isLargeText,
      'Haptic Alerts': () => settings.hapticAlerts,
      'Visual Alerts': () => settings.visualAlerts,
      'Screen Flash Alerts': () => settings.screenFlashAlerts,
    };
    for (final entry in switches.entries) {
      final before = entry.value();
      await tapText(tester, entry.key);
      expect(entry.value(), !before, reason: '${entry.key} did not respond');
    }
    for (final sound in ['Siren', 'Doorbell', 'Knock']) {
      final before = settings.allowedAlerts[sound];
      await tapText(tester, sound);
      expect(settings.allowedAlerts[sound], !before!, reason: '$sound switch did not respond');
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('darkMode'), isTrue);
    expect(prefs.getBool('visualAlerts'), isFalse);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('language, retention, quick replies and reset open, apply and close', (tester) async {
    ignoreAudioPlugin();
    await pumpSettings(tester);

    await tapText(tester, 'App Language');
    await tester.tap(find.byType(RadioListTile<String>).last);
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(settings.appLanguage, 'ur');
    expect(find.byType(AlertDialog), findsNothing);
    settings.setAppLanguage('en');
    await tester.pumpAndSettle();

    await tapText(tester, 'Default Retention Period');
    await tester.tap(find.byType(RadioListTile<int>).first);
    await tester.pumpAndSettle();
    expect(settings.defaultRetentionDays, 1);

    await tapText(tester, 'Manage quick replies');
    expect(find.text('Hello'), findsWidgets);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tapText(tester, 'Reset settings');
    await tester.tap(find.text('Reset'));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(settings.defaultRetentionDays, 7);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('the caption size slider responds', (tester) async {
    ignoreAudioPlugin();
    await pumpSettings(tester);
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(settings.captionTextSize, greaterThan(24));
    await tester.pump(const Duration(seconds: 2));
    await finish(tester);
  });

  testWidgets('both offline model tiles offer a download', (tester) async {
    ignoreAudioPlugin();
    await pumpSettings(tester);
    expect(find.text('Download'), findsNWidgets(2));
    expect(find.textContaining('73 MB'), findsOneWidget);
    expect(find.textContaining('161 MB'), findsOneWidget);
    await finish(tester);
  });
}
