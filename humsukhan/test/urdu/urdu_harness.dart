import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_monitor.dart';
import 'package:humsukhan/providers/providers.dart';
import 'package:humsukhan/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../environmental/fakes.dart';
import '../wellbeing/wellbeing_provider_test.dart' show FakeReminders;
import '../wellbeing/wellbeing_screen_test.dart' show MemoryStore;

/// Screens are checked at the size of a small Android phone.
const smallPhone = Size(360, 640);

/// Loads the app's own fonts, so text is measured and drawn as on a phone
/// rather than in the square test font.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load('NotoSans', ['fonts/noto_sans/NotoSans-Regular.ttf']);
  await load('NotoNastaliqUrdu', ['fonts/noto_sans/NotoNastaliqUrdu-Regular.ttf', 'fonts/noto_sans/NotoNastaliqUrdu-Bold.ttf']);
  final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

/// Plugins with no platform side in tests answer every call with nothing.
void silencePlugins() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in [
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'flutter_tts',
    'plugin.csdcorp.com/speech_to_text',
    'dexterous.com/flutter/local_notifications',
    'flutter.baseflow.com/permissions/methods',
    'com.humsukhan/environmental_monitor',
    'com.humsukhan.flashlight',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }
}

/// The providers the app creates, in their initial state, with Urdu as the
/// app language unless [language] says otherwise.
class AppProviders {
  AppProviders({String language = 'ur', List<ProfessionalSession> sessions = const []}) {
    SharedPreferences.setMockInitialValues({
      'appLanguage': language,
      'onboardingComplete': true,
      if (sessions.isNotEmpty) 'professionalSessions:guest': jsonEncode([for (final session in sessions) session.toJson()]),
    });
    EnvironmentalMonitoring.instance = FakeMonitor();
    settings = SettingsProvider();
    professional = ProfessionalProvider();
    wellbeing = WellbeingProvider(account: 'test', store: MemoryStore(), reminders: FakeReminders(), autoLoad: false);
  }

  late final SettingsProvider settings;
  late final ProfessionalProvider professional;
  late final WellbeingProvider wellbeing;

  Widget wrap(Widget home, {bool urdu = true, bool dark = false}) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => ConversationProvider()),
          ChangeNotifierProvider.value(value: professional),
          ChangeNotifierProvider(create: (_) => EnvironmentalProvider()),
          ChangeNotifierProvider(create: (_) => SpeechProvider()),
          ChangeNotifierProvider(create: (_) => QuickReplyProvider()),
          ChangeNotifierProvider.value(value: wellbeing),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forApp(urdu: urdu, dark: dark),
          locale: Locale(urdu ? 'ur' : 'en'),
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      );
}

/// Sets the test screen to [size] logical pixels and [textScale].
void useScreen(WidgetTester tester, {Size size = smallPhone, double textScale = 1.0}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Words that stay in Latin letters in Urdu: the app's name and the
/// abbreviation for artificial intelligence, both as Urdu writing uses them.
const latinAllowed = {'HumSukhan', 'AI'};

/// Every piece of text on screen (text, tooltips, accessibility labels) that
/// still has Latin words in it.
List<String> visibleEnglish(WidgetTester tester) {
  final found = <String>{};
  void check(String? text) {
    if (text == null) return;
    final words = RegExp(r'[A-Za-z][A-Za-z]+').allMatches(text).map((m) => m.group(0)!).where((w) => !latinAllowed.contains(w));
    if (words.isNotEmpty) found.add(text.replaceAll('\n', ' ').trim());
  }

  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    // Text tagged as English is English on purpose: a language's own name in
    // the language picker, or help shown in both languages.
    if (widget.locale?.languageCode == 'en') continue;
    check(widget.text.toPlainText(includeSemanticsLabels: false, includePlaceholders: false));
  }
  for (final widget in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    check(widget.message);
  }
  for (final widget in tester.widgetList<Semantics>(find.byType(Semantics))) {
    check(widget.properties.label);
    check(widget.properties.hint);
  }
  for (final widget in tester.widgetList<Icon>(find.byType(Icon))) {
    check(widget.semanticLabel);
  }
  return found.toList()..sort();
}
