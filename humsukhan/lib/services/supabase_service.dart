import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

/// Centralized Supabase initialization and access.
///
/// This service handles:
/// - Supabase client initialization
/// - Auth state management
/// - Database operations
/// - Row Level Security enforcement
///
/// All getters return safe defaults when Supabase is not initialized,
/// preventing null-check crashes during offline or failed-init scenarios.
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  bool _initialized = false;
  bool _supabaseReady = false;

  /// Whether Supabase was successfully initialized.
  bool get isReady => _supabaseReady;

  /// Returns the Supabase client, or null if not initialized.
  SupabaseClient? get client {
    if (!_supabaseReady) return null;
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('SupabaseService: client access failed: $e');
      return null;
    }
  }

  /// Returns the GoTrue auth client, or null if not initialized.
  GoTrueClient? get auth => client?.auth;

  /// Initialize Supabase. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        publishableKey: EnvConfig.supabaseAnonKey,
        debug: kDebugMode,
      );
      _supabaseReady = true;
      _initialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
      _initialized = true;
      // App continues without cloud sync
    }
  }

  /// Current authenticated user.
  User? get currentUser => auth?.currentUser;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => currentUser != null;

  /// Current user ID or empty string.
  String get userId => currentUser?.id ?? '';

  /// Listen to auth state changes. Returns empty stream if not initialized.
  Stream<AuthState> get onAuthStateChange =>
      auth?.onAuthStateChange ?? const Stream.empty();
}
