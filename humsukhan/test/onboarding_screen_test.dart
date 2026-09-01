import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/screens/onboarding_screen.dart';

void main() {
  testWidgets('onboarding exposes next, back, and get started controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [AppStrings.delegate],
        supportedLocales: [Locale('en')],
        home: OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Get Started'), findsOneWidget);
  });
}
