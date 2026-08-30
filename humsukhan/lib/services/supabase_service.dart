import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();
  bool _initialized = false;
  bool _supabaseReady = false;
  bool get isReady => _supabaseReady;
  bool get hasConfiguration => EnvConfig.hasSupabaseConfig;
  SupabaseClient? get client { if (!_supabaseReady) return null; try { return Supabase.instance.client; } catch (e) { debugPrint('SupabaseService: client access failed: $e'); return null; } }
  GoTrueClient? get auth => client?.auth;
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!EnvConfig.hasSupabaseConfig) { debugPrint('Supabase initialization skipped: SUPABASE_ANON_KEY is missing'); return; }
    try { await Supabase.initialize(url: EnvConfig.supabaseUrl, publishableKey: EnvConfig.supabaseAnonKey, debug: kDebugMode); _supabaseReady = true; debugPrint('Supabase initialized successfully'); } catch (e) { debugPrint('Supabase initialization failed: $e'); }
  }
  User? get currentUser => auth?.currentUser;
  bool get isAuthenticated => currentUser != null;
  String get userId => currentUser?.id ?? '';
  Stream<AuthState> get onAuthStateChange => auth?.onAuthStateChange ?? const Stream.empty();
}
