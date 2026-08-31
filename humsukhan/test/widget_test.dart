import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/main.dart';

void main() {
  testWidgets('App mounts startup screen without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const HumSukhanApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
