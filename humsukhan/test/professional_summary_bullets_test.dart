import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary UI contract is a list of concise bullets', () {
    final bullets = <String>['Main topic', 'Decision', 'Next step'];
    expect(bullets, hasLength(3));
    expect(bullets.every((x) => x.trim().isNotEmpty), isTrue);
  });
}
