import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/widgets/reusable_widgets.dart';

void main() {
  testWidgets('busy primary action renders as a disabled button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrimaryActionButton(
            label: 'Please wait…',
            icon: Icons.hourglass_top_rounded,
            onPressed: null,
          ),
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  test('active screens contain no empty button/tap callbacks', () {
    const paths = [
      'lib/screens/onboarding_screen.dart',
      'lib/screens/auth_screen.dart',
      'lib/screens/everyday_screen.dart',
      'lib/screens/environmental_screen.dart',
      'lib/screens/professional_screen.dart',
      'lib/screens/session_detail_screen.dart',
      'lib/screens/session_live_screen.dart',
      'lib/screens/settings_screen.dart',
    ];
    final emptyPressed = RegExp(r'onPressed\s*:\s*\(\)\s*\{\s*\}');
    final emptyTap = RegExp(r'onTap\s*:\s*\(\)\s*\{\s*\}');

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(matches(emptyPressed)), reason: '$path has a no-op onPressed callback');
      expect(source, isNot(matches(emptyTap)), reason: '$path has a no-op onTap callback');
    }
  });

  test('busy and recovery actions have explicit callbacks or disabled states', () {
    final onboarding = File('lib/screens/onboarding_screen.dart').readAsStringSync();
    final auth = File('lib/screens/auth_screen.dart').readAsStringSync();
    final liveSession = File('lib/screens/session_live_screen.dart').readAsStringSync();
    final sessionDetail = File('lib/screens/session_detail_screen.dart').readAsStringSync();
    final everyday = File('lib/screens/everyday_screen.dart').readAsStringSync();

    expect(onboarding, contains('onPressed: null,'));
    expect(auth, contains('onPressed: auth.isLoading ? null : _handleSubmit'));
    expect(auth, contains('onPressed: auth.isLoading ? null : _handleResetRequest'));
    expect(liveSession, contains('_isStoppingSession || _sessionStarting ? null : _stopSession'));
    expect(sessionDetail, contains('onRetry: () => DefaultTabController.of(context).animateTo(1)'));
    expect(everyday, contains('_isSavingConversation ? null'));
  });
}
