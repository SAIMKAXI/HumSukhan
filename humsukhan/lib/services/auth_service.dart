import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Authentication service using Supabase Auth.
///
/// Supports:
/// - Email/password sign up
/// - Email/password sign in
/// - Sign out
/// - Session persistence
/// - Auth state monitoring
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ?? AuthService._();
  AuthService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Current user.
  User? get currentUser => _supabase.currentUser;
  bool get isAuthenticated => _supabase.isAuthenticated;
  Stream<AuthState> get onAuthStateChange => _supabase.onAuthStateChange;

  /// Sign up with email and password.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );

      if (response.user != null) {
        debugPrint('Sign up successful: ${response.user!.id}');
        return AuthResult.success(response.user!);
      }
      return AuthResult.failure('Sign up failed: no user returned');
    } on AuthException catch (e) {
      debugPrint('Sign up auth error: ${e.message}');
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('Sign up error: $e');
      return AuthResult.failure('Sign up failed: $e');
    }
  }

  /// Sign in with email and password.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('Sign in successful: ${response.user!.id}');
        return AuthResult.success(response.user!);
      }
      return AuthResult.failure('Sign in failed: no user returned');
    } on AuthException catch (e) {
      debugPrint('Sign in auth error: ${e.message}');
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('Sign in error: $e');
      return AuthResult.failure('Sign in failed: $e');
    }
  }

  /// Sign in anonymously (for quick start without account).
  Future<AuthResult> signInAnonymously() async {
    try {
      final response = await _supabase.auth.signInAnonymously();

      if (response.user != null) {
        debugPrint('Anonymous sign in successful: ${response.user!.id}');
        return AuthResult.success(response.user!);
      }
      return AuthResult.failure('Anonymous sign in failed');
    } on AuthException catch (e) {
      debugPrint('Anonymous sign in error: ${e.message}');
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('Anonymous sign in error: $e');
      return AuthResult.failure('Anonymous sign in failed: $e');
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('Sign out successful');
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Reset password.
  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      debugPrint('Password reset error: $e');
      return false;
    }
  }
}

/// Result of an authentication operation.
class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  AuthResult.success(this.user)
      : success = true,
        errorMessage = null;

  AuthResult.failure(this.errorMessage)
      : success = false,
        user = null;
}
