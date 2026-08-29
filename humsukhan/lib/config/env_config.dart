/// Centralized environment configuration.
///
/// Secrets are passed via --dart-define-from-file=.env at build time.
/// Example: flutter build apk --dart-define-from-file=.env
///
/// For development, copy .env.example to .env and fill in your values.
class EnvConfig {
  EnvConfig._();

  // ── Supabase ──
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dxwlwnzdfdhfpeaeoagj.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // ── AI Services ──
  // Google AI Studio (Gemini Flash)
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String geminiModel = 'gemini-2.0-flash';

  // ── Retention ──
  static const int maxRetentionDays = 15;
}
