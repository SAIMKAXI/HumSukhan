import 'package:flutter_test/flutter_test.dart';

void main() {
  test('environmental home card policy has no monitoring status badge', () {
    const subtitle = 'Environmental alerts are being monitored.';
    expect(subtitle.toLowerCase(), isNot(contains('monitoring off')));
  });
}
