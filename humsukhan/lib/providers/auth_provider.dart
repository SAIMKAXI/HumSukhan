import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;
  User? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  String get userId => _user?.id ?? '';

  AuthProvider() { refresh(); }

  /// Rebinds auth state after Supabase becomes available.
  ///
  /// The app intentionally renders its first frame before Supabase finishes
  /// initializing, so auth state may be unavailable during construction.
  void refresh() {
    _authSubscription?.cancel();
    _user = _auth.currentUser;
    _authSubscription = _auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          _user = state.session?.user;
          break;
        case AuthChangeEvent.signedOut:
          _user = null;
          break;
        default:
          if (state.session != null) _user = state.session!.user;
          break;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<bool> signUp({required String email, required String password, String? name}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _auth.signUp(email: email, password: password, name: name);
    _isLoading = false;
    if (result.success && result.user != null) {
      _user = result.user;
      _error = null;
    } else {
      _user = null;
      _error = result.errorMessage ?? 'Account creation failed. Please try again.';
    }
    notifyListeners();
    return result.success && result.user != null;
  }

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _auth.signIn(email: email, password: password);
    _isLoading = false;
    if (result.success && result.hasActiveSession) {
      _user = result.user;
      _error = null;
    } else {
      _user = null;
      _error = result.errorMessage ?? 'Sign in failed: no active session was returned.';
    }
    notifyListeners();
    return result.success && result.hasActiveSession;
  }

  Future<bool> signInAnonymously() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _auth.signInAnonymously();
    _isLoading = false;
    if (result.success && result.hasActiveSession) {
      _user = result.user;
      _error = null;
    } else {
      _user = null;
      _error = result.errorMessage ?? 'Anonymous sign in failed.';
    }
    notifyListeners();
    return result.success && result.hasActiveSession;
  }

  Future<void> signOut() async {
    // Remove the authenticated UI immediately. Supabase revocation continues
    // afterward; no protected screen remains reachable through this provider.
    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  void clearError() { _error = null; notifyListeners(); }

  @override
  void dispose() { _authSubscription?.cancel(); super.dispose(); }
}
