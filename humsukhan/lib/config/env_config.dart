/// Centralized environment configuration.
class EnvConfig {
  EnvConfig._();
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dxwlwnzdfdhfpeaeoagj.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const String geminiModel = 'gemini-2.5-flash';
  static const int maxRetentionDays = 15;
  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
