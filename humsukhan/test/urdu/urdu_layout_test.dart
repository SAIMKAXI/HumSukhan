import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/screens/screens.dart';

import 'urdu_harness.dart';

/// Every screen, in Urdu with the app's own fonts, fits a small phone at the
/// normal text size and at large text, with nothing overflowing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  silencePlugins();
  setUpAll(loadAppFonts);

  final session = ProfessionalSession(
    title: 'ریاضی کی کلاس — الجبرا اور جیومیٹری کا تفصیلی جائزہ',
    type: SessionType.class_,
    captionLanguage: 'Urdu',
    captions: [
      Caption(text: 'آج ہم الجبرا کے بنیادی اصول پڑھیں گے اور پھر چند مشقیں حل کریں گے۔', language: 'Urdu'),
      Caption(text: 'Please open chapter four, page twelve.', language: 'English'),
    ],
  );

  final screens = <String, Widget Function()>{
    'Splash': () => SplashScreen(onComplete: () {}),
    'Onboarding': () => const OnboardingScreen(),
    'Sign in': () => const AuthScreen(),
    'Set new password': () => const AuthScreen(recoveryMode: true),
    'Main navigation': () => const MainScaffold(),
    'Home': () => const HomeScreen(),
    'Everyday': () => const EverydayScreen(),
    'Professional': () => const ProfessionalScreen(),
    'Alerts': () => const EnvironmentalScreen(),
    'Settings': () => const SettingsScreen(),
    'Wellbeing': () => const WellbeingScreen(),
    'Wellbeing ideas': () => const SupportScreen(state: MoodState.severalLowDays),
    'Urgent help': () => const HelpNowScreen(),
    'Live session': () => SessionLiveScreen(sessionId: session.id),
    'Session details': () => SessionDetailScreen(sessionId: session.id),
  };

  for (final textScale in [1.0, 1.3]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits a small phone in Urdu at text scale $textScale', (tester) async {
        final overflows = <String>[];
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed')) {
            overflows.add(text.split('\n').first);
          } else {
            original?.call(details);
          }
        };

        useScreen(tester, textScale: textScale);
        final app = AppProviders(sessions: [session]);
        await tester.runAsync(app.wellbeing.load);
        await tester.pumpWidget(app.wrap(entry.value()));
        await tester.runAsync(pumpEventQueue);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpWidget(const SizedBox());
        // Restored before expect, which the test framework requires.
        FlutterError.onError = original;

        expect(overflows, isEmpty, reason: '${entry.key} at text scale $textScale:\n${overflows.join('\n')}');
      });
    }
  }
}
