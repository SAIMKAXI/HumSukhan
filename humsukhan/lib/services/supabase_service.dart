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
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  bool _initialized = false;

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;

  /// Initialize Supabase. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        publishableKey: EnvConfig.supabaseAnonKey,
        debug: kDebugMode,
      );
      _initialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
      rethrow;
    }
  }

  /// Current authenticated user.
  User? get currentUser => auth.currentUser;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => currentUser != null;

  /// Current user ID or empty string.
  String get userId => currentUser?.id ?? '';

  /// Listen to auth state changes.
  Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;
}
