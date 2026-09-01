import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;
  User? _user;
  bool _isLoading = false;
  bool _isPasswordRecovery = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isPasswordRecovery => _isPasswordRecovery;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  String get userId => _user?.id ?? '';

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = _auth.currentUser;
    _authSubscription = _auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          _user = state.session?.user;
          break;
        case AuthChangeEvent.passwordRecovery:
          _user = state.session?.user ?? _auth.currentUser;
          _isPasswordRecovery = _user != null;
          break;
        case AuthChangeEvent.signedOut:
          _user = null;
          _isPasswordRecovery = false;
          _error = null;
          break;
        default:
          if (state.session != null) _user = state.session!.user;
          break;
      }
      notifyListeners();
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    _beginLoading();
    final result = await _auth.signUp(email: email, password: password, name: name);
    _finishLoading(result);
    return result.success && result.user != null && result.hasActiveSession;
  }

  Future<bool> signIn({required String email, required String password}) async {
    _beginLoading();
    final result = await _auth.signIn(email: email, password: password);
    _finishLoading(result);
    return result.success && result.hasActiveSession;
  }

  Future<bool> resetPassword(String email) async {
    _beginLoading();
    final result = await _auth.resetPassword(email);
    _isLoading = false;
    _error = result.success ? null : result.errorMessage;
    notifyListeners();
    return result.success;
  }

  Future<bool> updatePassword(String password) async {
    _beginLoading();
    final result = await _auth.updatePassword(password);
    _isLoading = false;
    if (result.success) {
      _user = result.user ?? _user;
      _isPasswordRecovery = false;
      _error = null;
    } else {
      _error = result.errorMessage ?? 'Unable to update your password.';
    }
    notifyListeners();
    return result.success;
  }

  Future<bool> signInAnonymously() async {
    _beginLoading();
    final result = await _auth.signInAnonymously();
    _finishLoading(result);
    return result.success && result.hasActiveSession;
  }

  Future<void> signOut() async {
    _user = null;
    _error = null;
    _isPasswordRecovery = false;
    _isLoading = false;
    notifyListeners();
    await _auth.signOut();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _beginLoading() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }

  void _finishLoading(AuthResult result) {
    _isLoading = false;
    if (result.success && result.hasActiveSession) {
      _user = result.user;
      _isPasswordRecovery = false;
      _error = null;
    } else {
      _user = null;
      _error = result.errorMessage ?? 'Authentication failed. Please try again.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
