import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/state_machine.dart';

/// The account on this phone.
enum AuthStatus {
  signedOut,
  signedIn,

  /// Signed in by a password-reset link, and must set a new password before
  /// using the app.
  recoveringPassword,
}

/// A reset link can arrive signed in or out; setting the new password, or
/// any ordinary sign-in, finishes recovery.
const authTransitions = <AuthStatus, Set<AuthStatus>>{
  AuthStatus.signedOut: {AuthStatus.signedIn, AuthStatus.recoveringPassword},
  AuthStatus.signedIn: {AuthStatus.signedOut, AuthStatus.recoveringPassword},
  AuthStatus.recoveringPassword: {AuthStatus.signedIn, AuthStatus.signedOut},
};

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;
  final _status = StateMachine(AuthStatus.signedOut, authTransitions);
  User? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  User? get user => _user;
  bool get isLoading => _isLoading;
  AuthStatus get status => _status.state;
  bool get isPasswordRecovery => _status.state == AuthStatus.recoveringPassword;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  String get userId => _user?.id ?? '';

  AuthProvider() {
    refresh();
  }

  /// Rebinds auth state after Supabase becomes available.
  ///
  /// The app renders its first frame before Supabase finishes initializing,
  /// so auth state may be unavailable during construction.
  void refresh() {
    _authSubscription?.cancel();
    _setUser(_auth.currentUser);
    _authSubscription = _auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          _setUser(state.session?.user, recovering: false);
          break;
        case AuthChangeEvent.passwordRecovery:
          _setUser(state.session?.user ?? _auth.currentUser, recovering: true);
          break;
        case AuthChangeEvent.signedOut:
          _setUser(null);
          _error = null;
          break;
        default:
          if (state.session != null) _setUser(state.session!.user);
          break;
      }
      notifyListeners();
    });
    notifyListeners();
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
      _setUser(result.user ?? _user, recovering: false);
      _error = null;
    } else {
      _error = result.errorMessage ?? 'Unable to update your password.';
    }
    notifyListeners();
    return result.success;
  }

  Future<void> signOut() async {
    _setUser(null);
    _error = null;
    _isLoading = false;
    notifyListeners();
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
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
      _setUser(result.user, recovering: false);
      _error = null;
    } else {
      _setUser(null);
      _error = result.errorMessage ?? 'Authentication failed. Please try again.';
    }
    notifyListeners();
  }

  /// Records who is signed in. With no user the account is signed out;
  /// [recovering] says whether a signed-in account is recovering its
  /// password, and when it is left out recovery carries on as it was.
  void _setUser(User? user, {bool? recovering}) {
    _user = user;
    if (user == null) {
      _status.moveTo(AuthStatus.signedOut);
    } else if (recovering ?? isPasswordRecovery) {
      _status.moveTo(AuthStatus.recoveringPassword);
    } else {
      _status.moveTo(AuthStatus.signedIn);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
