import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/screens/splash_screen.dart';

void main() {
  testWidgets('startup semantics are exposed through the semantics tree',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [AppStrings.delegate],
        supportedLocales: [Locale('en')],
        home: SplashScreen(onComplete: _noop),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('HumSukhan startup'), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-brand-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-app-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-app-tagline')), findsOneWidget);
  });

  testWidgets('completion remains single-fire when the timer expires',
      (tester) async {
    var completions = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppStrings.delegate],
        supportedLocales: const [Locale('en')],
        home: SplashScreen(onComplete: () => completions++),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(seconds: 1));

    expect(completions, 1);
  });
}

void _noop() {}
