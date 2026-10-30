import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'database_service.dart';
import '../config/env_config.dart';
import 'supabase_service.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  SupabaseService get _supabase => SupabaseService.instance;
  bool get isAvailable => _supabase.auth != null;
  User? get currentUser => _supabase.currentUser;
  bool get isAuthenticated => _supabase.isAuthenticated;
  Stream<AuthState> get onAuthStateChange => _supabase.onAuthStateChange;

  static final RegExp _emailPattern =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  /// Supabase Auth accepts at most 72 characters. Passwords made under the
  /// old exactly-8 rule still fit.
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 72;
  static final RegExp _strongPassword =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9])');

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String? validateEmail(String email) {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) return 'Please enter your email address.';
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? validatePassword(String password) {
    if (password.length < minPasswordLength || password.length > maxPasswordLength) {
      return 'Password must be $minPasswordLength to $maxPasswordLength characters.';
    }
    if (!_strongPassword.hasMatch(password)) {
      return 'Password must contain uppercase, lowercase, number, and special character.';
    }
    return null;
  }

  /// What to tell the user when create-account refuses a sign-up. Its 400,
  /// 409 and 429 answers carry a message written for the user (the details
  /// were refused, the email is taken, too many new accounts); anything else
  /// is reported generically.
  @visibleForTesting
  static String signUpFailureMessage(int status, Object? details) {
    final message = details is Map ? details['error'] : null;
    if (const {400, 409, 429}.contains(status) && message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return 'Account creation failed. Please try again.';
  }

  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    if (!isAvailable) {
      return AuthResult.failure(
        'Authentication unavailable. Please check your connection and try again.',
      );
    }

    final emailError = validateEmail(email);
    if (emailError != null) return AuthResult.failure(emailError);
    final passwordError = validatePassword(password);
    if (passwordError != null) return AuthResult.failure(passwordError);

    final normalizedEmail = normalizeEmail(email);
    final normalizedName = name?.trim();

    try {
      await _supabase.client!.functions
          .invoke(
            'create-account',
            body: {
              'email': normalizedEmail,
              'password': password,
              if (normalizedName?.isNotEmpty == true) 'name': normalizedName,
            },
          )
          .timeout(const Duration(seconds: 20));

      final response = await _supabase.auth!
          .signInWithPassword(
            email: normalizedEmail,
            password: password,
          )
          .timeout(const Duration(seconds: 20));
      final user = response.user;
      if (user == null || response.session == null) {
        return AuthResult.failure(
          'Account was created, but sign in could not be completed. Please try again.',
        );
      }

      await ensureProfile(user, name: normalizedName);
      return AuthResult.success(user, hasActiveSession: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthMessage(e));
    } on FunctionException catch (e) {
      debugPrint('Sign up function error: ${e.status}');
      return AuthResult.failure(signUpFailureMessage(e.status, e.details));
    } on Exception catch (e) {
      debugPrint('Sign up error: $e');
      return AuthResult.failure('Account creation failed. Check your connection and try again.');
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!isAvailable) {
      return AuthResult.failure(
        'Authentication unavailable. Please check your connection and try again.',
      );
    }

    final emailError = validateEmail(email);
    if (emailError != null) return AuthResult.failure(emailError);
    if (password.isEmpty) return AuthResult.failure('Please enter your password.');

    try {
      final response = await _supabase.auth!
          .signInWithPassword(
            email: normalizeEmail(email),
            password: password,
          )
          .timeout(const Duration(seconds: 20));
      final user = response.user;
      if (user == null || response.session == null) {
        return AuthResult.failure('Sign in failed: no active session was returned.');
      }

      await ensureProfile(user);
      return AuthResult.success(user, hasActiveSession: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthMessage(e));
    } on Exception catch (e) {
      debugPrint('Sign in error: $e');
      return AuthResult.failure('Sign in failed. Check your connection and try again.');
    }
  }

  Future<void> ensureProfile(User user, {String? name}) async {
    if (!isAvailable) return;
    try {
      final existing = await DatabaseService.instance.fetchProfile(user.id);
      if (existing != null) return;

      final metadataName = user.userMetadata?['name']?.toString().trim();
      final resolvedName = (name?.trim().isNotEmpty == true)
          ? name!.trim()
          : (metadataName?.isNotEmpty == true ? metadataName! : 'User');

      await DatabaseService.instance.upsertProfile(
        UserProfile(id: user.id, name: resolvedName),
      );
    } catch (e) {
      debugPrint('Profile ensure error: $e');
    }
  }

  Future<AuthResult> resetPassword(String email) async {
    if (!isAvailable) {
      return AuthResult.failure(
        'Authentication unavailable. Please check your connection and try again.',
      );
    }
    final emailError = validateEmail(email);
    if (emailError != null) return AuthResult.failure(emailError);

    try {
      await _supabase.auth!
          .resetPasswordForEmail(normalizeEmail(email), redirectTo: EnvConfig.authRedirectUrl)
          .timeout(const Duration(seconds: 20));
      return const AuthResult.success(null);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthMessage(e));
    } on Exception catch (e) {
      debugPrint('Password reset error: $e');
      return AuthResult.failure('Unable to send the reset email. Check your connection and try again.');
    }
  }

  Future<AuthResult> updatePassword(String password) async {
    if (!isAvailable) {
      return AuthResult.failure(
        'Authentication unavailable. Please check your connection and try again.',
      );
    }
    final passwordError = validatePassword(password);
    if (passwordError != null) return AuthResult.failure(passwordError);

    try {
      final response = await _supabase.auth!
          .updateUser(UserAttributes(password: password))
          .timeout(const Duration(seconds: 20));
      final user = response.user ?? currentUser;
      if (user == null) return AuthResult.failure('Password updated, but your session is unavailable.');
      return AuthResult.success(user, hasActiveSession: isAuthenticated);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthMessage(e));
    } on Exception catch (e) {
      debugPrint('Password update error: $e');
      return AuthResult.failure('Unable to update your password. Check your connection and try again.');
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await _supabase.auth!.signOut().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  String _friendlyAuthMessage(AuthException exception) {
    final message = exception.message.trim();
    if (message.isEmpty) return 'Authentication failed. Please try again.';
    return message;
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;
  final bool hasActiveSession;

  const AuthResult.success(this.user, {this.hasActiveSession = true})
      : success = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage)
      : success = false,
        user = null,
        hasActiveSession = false;
}
