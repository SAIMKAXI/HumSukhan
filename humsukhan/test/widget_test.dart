import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/main.dart';

Future<void> _waitForSplash(WidgetTester tester) async {
  for (var i = 0; i < 24; i++) {
    if (find.text('HumSukhan').evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('App renders splash screen without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const HumSukhanApp());
    await _waitForSplash(tester);

    expect(find.text('HumSukhan'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
