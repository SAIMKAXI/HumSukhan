import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/auth_service.dart';

void main() {
  test('recovery contract shares the same strong password policy', () {
    expect(AuthService.validatePassword('Aa1!bbbb'), isNull);
    expect(AuthService.validatePassword('short'), isNotNull);
  });
}
