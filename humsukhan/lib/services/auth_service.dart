import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'database_service.dart';
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

  static final RegExp _strongEightCharPassword =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8}$');

  static String? validatePassword(String password) {
    if (password.length != 8) {
      return 'Password must be exactly 8 characters.';
    }
    if (!_strongEightCharPassword.hasMatch(password)) {
      return 'Password must contain uppercase, lowercase, number, and special character.';
    }
    return null;
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

    final passwordError = validatePassword(password);
    if (passwordError != null) return AuthResult.failure(passwordError);

    final normalizedName = name?.trim();

    try {
      final response = await _supabase.auth!.signUp(
        email: email.trim(),
        password: password,
        data: normalizedName?.isNotEmpty == true ? {'name': normalizedName} : null,
      );
      final user = response.user;
      if (user == null) {
        return AuthResult.failure('Account creation failed: no user returned.');
      }

      if (response.session != null) {
        await ensureProfile(user, name: normalizedName);
      }

      return AuthResult.success(user, hasActiveSession: response.session != null);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('Sign up error: $e');
      return AuthResult.failure('Account creation failed. Please try again.');
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

    try {
      final response = await _supabase.auth!.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null || response.session == null) {
        return AuthResult.failure('Sign in failed: no active session was returned.');
      }

      await ensureProfile(user);
      return AuthResult.success(user, hasActiveSession: true);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('Sign in error: $e');
      return AuthResult.failure('Sign in failed. Please try again.');
    }
  }

  /// Ensure a profile exists for the authenticated Supabase user.
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

  Future<AuthResult> signInAnonymously() async {
    if (!isAvailable) {
      return AuthResult.failure(
        'Authentication unavailable. Please check your connection and try again.',
      );
    }
    try {
      final response = await _supabase.auth!.signInAnonymously();
      if (response.user != null) {
        return AuthResult.success(response.user!, hasActiveSession: response.session != null);
      }
      return AuthResult.failure('Anonymous sign in failed.');
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('Anonymous sign in error: $e');
      return AuthResult.failure('Anonymous sign in failed.');
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await _supabase.auth!.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  Future<bool> resetPassword(String email) async {
    if (!isAvailable) return false;
    try {
      await _supabase.auth!.resetPasswordForEmail(email.trim());
      return true;
    } catch (_) {
      return false;
    }
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
