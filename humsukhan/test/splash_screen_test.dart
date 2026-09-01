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
        locale: const Locale('en'),
        home: SplashScreen(onComplete: () => completionCount++),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('splash-brand-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-app-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-app-tagline')), findsOneWidget);
    expect(completionCount, 0);

    await tester.pump(const Duration(milliseconds: 2199));
    expect(completionCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(completionCount, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(completionCount, 1);
  });
}
