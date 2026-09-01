import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_strings.dart';
import 'package:humsukhan/screens/splash_screen.dart';

void main() {
  testWidgets('renders branded startup and completes exactly once', (tester) async {
    var completionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppStrings.delegate],
        supportedLocales: const [Locale('en')],
        home: SplashScreen(onComplete: () => completionCount++),
      ),
    );

    expect(find.text('HumSukhan'), findsOneWidget);
    expect(find.text('Accessibility-first AI Companion'), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-app-name')), findsOneWidget);
    expect(completionCount, 0);

    await tester.pump(const Duration(milliseconds: 2199));
    expect(completionCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(completionCount, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(completionCount, 1);
  });
}
