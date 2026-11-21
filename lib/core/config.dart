/// Configuración inyectada con `--dart-define-from-file=env.json`.
/// `env.json` no se sube al repositorio (ver `env.example.json`).
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get completa => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
