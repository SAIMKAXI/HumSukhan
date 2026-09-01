import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/auth_service.dart';

void main() {
  group('AuthService email validation', () {
    test('normalizes valid email', () {
      expect(AuthService.normalizeEmail('  User@Example.COM '), 'user@example.com');
      expect(AuthService.validateEmail(' User@Example.COM '), isNull);
    });

    test('rejects empty and malformed email', () {
      expect(AuthService.validateEmail(''), isNotNull);
      expect(AuthService.validateEmail('user@'), isNotNull);
      expect(AuthService.validateEmail('user example.com'), isNotNull);
    });
  });

  group('AuthService password validation', () {
    test('accepts the required eight-character strong password', () {
      expect(AuthService.validatePassword('Aa1!bbbb'), isNull);
    });

    test('rejects passwords that violate the product policy', () {
      expect(AuthService.validatePassword('Aa1!bbb'), isNotNull);
      expect(AuthService.validatePassword('aa1!bbbb'), isNotNull);
      expect(AuthService.validatePassword('AA1!BBBB'), isNotNull);
      expect(AuthService.validatePassword('Aa!bbbbb'), isNotNull);
      expect(AuthService.validatePassword('Aa1bbbbc'), isNotNull);
    });
  });
}
