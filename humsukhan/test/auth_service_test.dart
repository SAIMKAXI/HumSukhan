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
    test('accepts strong passwords of 8 to 72 characters', () {
      // Passwords made under the old exactly-8 rule still work.
      expect(AuthService.validatePassword('Aa1!bbbb'), isNull);
      expect(AuthService.validatePassword('Longer-Passw0rd-is-fine'), isNull);
      expect(AuthService.validatePassword('Aa1!${'x' * 68}'), isNull);
    });

    test('rejects passwords that violate the product policy', () {
      expect(AuthService.validatePassword('Aa1!bbb'), isNotNull);
      expect(AuthService.validatePassword('Aa1!${'x' * 69}'), isNotNull);
      expect(AuthService.validatePassword('aa1!bbbb'), isNotNull);
      expect(AuthService.validatePassword('AA1!BBBB'), isNotNull);
      expect(AuthService.validatePassword('Aa!bbbbb'), isNotNull);
      expect(AuthService.validatePassword('Aa1bbbbc'), isNotNull);
    });
  });

  group('AuthService sign-up failures', () {
    test('shows the server\'s own message for a taken email, refused details or too many sign-ups', () {
      const taken = 'An account with this email already exists. Please sign in or reset your password.';
      expect(AuthService.signUpFailureMessage(409, {'error': taken}), taken);
      expect(AuthService.signUpFailureMessage(429, {'error': 'Too many new accounts right now.'}), 'Too many new accounts right now.');
      expect(AuthService.signUpFailureMessage(400, {'error': 'Please enter a valid email address.'}), 'Please enter a valid email address.');
    });

    test('anything else is reported generically', () {
      const generic = 'Account creation failed. Please try again.';
      expect(AuthService.signUpFailureMessage(500, {'error': 'database is down'}), generic);
      expect(AuthService.signUpFailureMessage(409, 'not a map'), generic);
      expect(AuthService.signUpFailureMessage(429, {'error': ''}), generic);
    });
  });
}
