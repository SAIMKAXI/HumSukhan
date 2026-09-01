import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/screens/splash_screen.dart';

void main() {
  testWidgets('Splash renders branded loading state', (WidgetTester tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ur')],
        home: SplashScreen(onComplete: () => completed = true),
      ),
    );
    await tester.pump();

    final startupFinder = find.byKey(const ValueKey('humsukhan-startup'));
    expect(startupFinder, findsOneWidget);

    final startupSemantics = tester.widget<Semantics>(startupFinder);
    expect(startupSemantics.identifier, 'humsukhan-startup');
    expect(startupSemantics.properties.label, 'HumSukhan startup');
    expect(startupSemantics.properties.liveRegion, isTrue);
    expect(find.text('HumSukhan'), findsOneWidget);
    expect(find.text('Accessibility-first AI Companion'), findsOneWidget);
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 2200));
    expect(completed, isTrue);
  });

  testWidgets('Splash uses localized startup content', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ur'),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ur')],
        home: SplashScreen(onComplete: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('HumSukhan'), findsOneWidget);
    expect(find.text('قابلِ رسائی AI معاون'), findsOneWidget);
  });
}
