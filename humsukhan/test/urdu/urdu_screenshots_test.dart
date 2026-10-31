import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/screens/screens.dart';

import 'urdu_harness.dart';

/// Renders every screen in Urdu, with the app's fonts, to PNG files for a
/// person to look over. Runs only when asked:
///
///   flutter test test/urdu/urdu_screenshots_test.dart --dart-define=SCREENSHOT_DIR=/tmp/shots
void main() {
  const dir = String.fromEnvironment('SCREENSHOT_DIR');
  TestWidgetsFlutterBinding.ensureInitialized();
  silencePlugins();
  setUpAll(loadAppFonts);

  final session = ProfessionalSession(
    title: 'ریاضی کی کلاس',
    type: SessionType.class_,
    captionLanguage: 'Urdu',
    captions: [
      Caption(text: 'آج ہم الجبرا کے بنیادی اصول پڑھیں گے اور پھر چند مشقیں حل کریں گے۔', language: 'Urdu'),
      Caption(text: 'Please open chapter four, page twelve.', language: 'English'),
    ],
  );

  final screens = <String, Widget Function()>{
    'splash': () => SplashScreen(onComplete: () {}),
    'onboarding': () => const OnboardingScreen(),
    'sign_in': () => const AuthScreen(),
    'new_password': () => const AuthScreen(recoveryMode: true),
    'home': () => const MainScaffold(),
    'everyday': () => const EverydayScreen(),
    'professional': () => const ProfessionalScreen(),
    'alerts': () => const EnvironmentalScreen(),
    'settings': () => const SettingsScreen(),
    'wellbeing': () => const WellbeingScreen(),
    'wellbeing_ideas': () => const SupportScreen(state: MoodState.lowDay),
    'urgent_help': () => const HelpNowScreen(),
    'live_session': () => SessionLiveScreen(sessionId: session.id),
    'session_details': () => SessionDetailScreen(sessionId: session.id),
  };

  for (final entry in screens.entries) {
    for (final (suffix, size) in [('', smallPhone), ('_full', const Size(360, 1800))]) {
      testWidgets('screenshot ${entry.key}$suffix', (tester) async {
        // Audio players open event streams with generated channel names that
        // cannot be stubbed ahead of time; those errors don't affect a picture.
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exception is! MissingPluginException) original?.call(details);
        };
        addTearDown(() => FlutterError.onError = original);
        useScreen(tester, size: size);
        final app = AppProviders(sessions: [session]);
        final key = GlobalKey();
        await tester.runAsync(app.wellbeing.load);
        await tester.pumpWidget(RepaintBoundary(key: key, child: app.wrap(entry.value())));
        await tester.runAsync(pumpEventQueue);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/${entry.key}$suffix.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox());
        FlutterError.onError = original;
      }, skip: dir.isEmpty);
    }
  }
}
