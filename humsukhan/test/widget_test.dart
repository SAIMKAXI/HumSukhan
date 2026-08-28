import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const HumSukhanApp());
    await tester.pumpAndSettle();
    expect(find.text('HumSukhan'), findsOneWidget);
  });
}
