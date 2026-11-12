/// Supabase project used by the API, for the chat Realtime signals only.
///
/// The defaults point to the project of the published API
/// (`wss://pvacwfypqsstdrfxajkg.supabase.co/realtime/v1/websocket`). The key
/// is the publishable anon key, which is public by design and only works
/// with the private channel policies; never put a service key here.
/// `--dart-define` can still override both for another environment.
class RealtimeConfig {
  const RealtimeConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pvacwfypqsstdrfxajkg.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2YWN3ZnlwcXNzdGRyZnhhamtnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzOTc0NzEsImV4cCI6MjEwODk3MzQ3MX0.TzVo1if-cy03BwtCioOJpUNr7AuWxAT9yAssj4DZ8Qs',
  );

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

  /// `https://<ref>.supabase.co` → `wss://<ref>.supabase.co/realtime/v1`;
  /// the Realtime client appends `/websocket`.
  static String get endpoint {
    final base = Uri.parse(supabaseUrl);
    return base.replace(scheme: 'wss', path: '/realtime/v1').toString();
  }
}
