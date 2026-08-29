/// Centralized environment configuration.
///
/// IMPORTANT: In production, these values should come from environment
/// variables or a secure configuration service. For now, they are
/// hardcoded as this is a prototype.
class EnvConfig {
  EnvConfig._();

  // ── Supabase ──
  static const String supabaseUrl = 'https://dxwlwnzdfdhfpeaeoagj.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4d2x3bnpkZmRoZnBlYWVvYWdqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwMjI4MDcsImV4cCI6MjEwMzU5ODgwN30.IGXg82guqPBE0L6CH1xj5KN0xO4jS1Dj84CK_LuNDBY';

  // ── AI Services ──
  // Google AI Studio (Gemini Flash) - set via environment
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String geminiModel = 'gemini-2.0-flash';

  // ── Retention ──
  static const int maxRetentionDays = 15;
}
