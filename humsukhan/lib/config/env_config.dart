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
  static const int maxRetentionDays = 15;

  /// Where account emails (password reset) send the user back to: this app,
  /// through the deep link declared in AndroidManifest.xml and Info.plist.
  /// It must also be listed under Supabase Auth > URL Configuration >
  /// Redirect URLs, or Supabase falls back to the project's Site URL.
  static const String authRedirectUrl = 'com.humsukhan.humsukhan://login-callback/';
  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
