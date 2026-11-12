/// Supabase project used by the API, for the chat Realtime signals only.
/// Both values are public (URL and publishable/anon key); never put a
/// service key here. Without them the chat still works over HTTP.
class RealtimeConfig {
  const RealtimeConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

  /// `https://<ref>.supabase.co` → `wss://<ref>.supabase.co/realtime/v1`.
  static String get endpoint {
    final base = Uri.parse(supabaseUrl);
    return base.replace(scheme: 'wss', path: '/realtime/v1').toString();
  }
}
