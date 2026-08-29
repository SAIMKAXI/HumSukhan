import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/main.dart';

void main() {
  testWidgets('App renders splash screen without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const HumSukhanApp());
    await tester.pump();
    // Verify the splash screen shows the app name
    expect(find.text('HumSukhan'), findsOneWidget);
    // Verify logo is shown
    expect(find.byType(Image), findsOneWidget);
  });
}
