import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:humsukhan/providers/auth_provider.dart';
import 'package:humsukhan/screens/auth_screen.dart';

void main() {
  testWidgets('sign-in screen exposes forgot password without rebuilding auth flow', (tester) async {
    final auth = AuthProvider();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('forgot password screen accepts an email and exposes reset action', (tester) async {
    final auth = AuthProvider();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
