import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/screens/screens.dart';

import 'urdu_harness.dart';

/// Every screen, opened with Urdu as the app language, shows no English.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  silencePlugins();
  setUpAll(loadAppFonts);

  // Tall enough that every item of a long list is built and checked.
  const tallPhone = Size(360, 4000);

  Future<AppProviders> open(WidgetTester tester, Widget Function(AppProviders app) screen, {List<ProfessionalSession> sessions = const []}) async {
    useScreen(tester, size: tallPhone);
    final app = AppProviders(sessions: sessions);
    await tester.runAsync(app.wellbeing.load);
    await tester.pumpWidget(app.wrap(screen(app)));
    await tester.runAsync(pumpEventQueue);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    return app;
  }

  void expectAllUrdu(WidgetTester tester, String screen) {
    final english = visibleEnglish(tester);
    expect(english, isEmpty, reason: '$screen shows English:\n${english.join('\n')}');
  }

  final session = ProfessionalSession(
    title: 'ریاضی کی کلاس',
    type: SessionType.class_,
    captionLanguage: 'Urdu',
    captions: [Caption(text: 'آج ہم الجبرا پڑھیں گے', language: 'Urdu')],
  );

  final screens = <String, Widget Function(AppProviders)>{
    'Splash': (_) => SplashScreen(onComplete: () {}),
    'Onboarding': (_) => const OnboardingScreen(),
    'Sign in': (_) => const AuthScreen(),
    'Set new password': (_) => const AuthScreen(recoveryMode: true),
    'Main navigation': (_) => const MainScaffold(),
    'Home': (_) => const HomeScreen(),
    'Everyday': (_) => const EverydayScreen(),
    'Professional': (_) => const ProfessionalScreen(),
    'Alerts': (_) => const EnvironmentalScreen(),
    'Settings': (_) => const SettingsScreen(),
    'Wellbeing': (_) => const WellbeingScreen(),
    'Wellbeing ideas': (_) => const SupportScreen(state: MoodState.lowDay),
    'Urgent help': (_) => const HelpNowScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} is all Urdu', (tester) async {
      await open(tester, entry.value);
      expectAllUrdu(tester, entry.key);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Live session is all Urdu', (tester) async {
    await open(tester, (_) => SessionLiveScreen(sessionId: session.id), sessions: [session]);
    expectAllUrdu(tester, 'Live session');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Session details is all Urdu', (tester) async {
    await open(tester, (_) => SessionDetailScreen(sessionId: session.id), sessions: [session]);
    expectAllUrdu(tester, 'Session details');
    await tester.pumpWidget(const SizedBox());
  });
}
