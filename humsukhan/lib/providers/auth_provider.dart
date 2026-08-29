import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

/// Authentication state management.
///
/// Manages sign up, sign in, sign out, and session state.
/// Listens to Supabase auth state changes.
class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;

  User? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  String get userId => _user?.id ?? '';

  AuthProvider() {
    _init();
  }

  void _init() {
    // Check for existing session
    _user = _auth.currentUser;

    // Listen to auth state changes
    _authSubscription = _auth.onAuthStateChange.listen((state) {
      final event = state.event;
      final session = state.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          _user = session?.user;
          debugPrint('Auth: signed in / token refreshed');
          break;
        case AuthChangeEvent.signedOut:
          _user = null;
          debugPrint('Auth: signed out');
          break;
        case AuthChangeEvent.passwordRecovery:
          debugPrint('Auth: password recovery');
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }

  /// Sign up with email and password.
  Future<bool> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _auth.signUp(email: email, password: password, name: name);

    _isLoading = false;
    if (result.success) {
      _user = result.user;
      _error = null;
    } else {
      _error = result.errorMessage;
    }
    notifyListeners();
    return result.success;
  }

  /// Sign in with email and password.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _auth.signIn(email: email, password: password);

    _isLoading = false;
    if (result.success) {
      _user = result.user;
      _error = null;
    } else {
      _error = result.errorMessage;
    }
    notifyListeners();
    return result.success;
  }

  /// Sign in anonymously.
  Future<bool> signInAnonymously() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _auth.signInAnonymously();

    _isLoading = false;
    if (result.success) {
      _user = result.user;
      _error = null;
    } else {
      _error = result.errorMessage;
    }
    notifyListeners();
    return result.success;
  }

  /// Sign out.
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _auth.signOut();
    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
