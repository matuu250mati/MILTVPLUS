const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Accepts the canonical Supabase project URL, optionally with trailing slashes.
/// Paths such as /rest/v1, dashboard URLs, query strings, and fragments are rejected.
String normalizeSupabaseUrl(String value) {
  var normalized = value.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

bool isValidSupabaseUrl(String value) {
  final normalized = normalizeSupabaseUrl(value);
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !uri.host.endsWith('.supabase.co') ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }

  final projectRef = uri.host.substring(0, uri.host.length - '.supabase.co'.length);
  return RegExp(r'^[a-z0-9-]+$').hasMatch(projectRef);
}

String get normalizedSupabaseUrl => normalizeSupabaseUrl(supabaseUrl);

String? get supabaseConfigurationError {
  if (supabaseUrl.trim().isEmpty) {
    return 'Falta SUPABASE_URL. Configurá la URL del proyecto en los secretos de GitHub Actions.';
  }
  if (!isValidSupabaseUrl(supabaseUrl)) {
    return 'SUPABASE_URL no es válida. Usá https://<project-ref>.supabase.co, sin /rest/v1, rutas, parámetros ni URL del panel de Supabase.';
  }
  if (supabaseAnonKey.trim().isEmpty) {
    return 'Falta SUPABASE_ANON_KEY. Configurá la clave publishable/anon del proyecto; nunca uses service_role en la app.';
  }
  return null;
}

bool get isSupabaseConfigured => supabaseConfigurationError == null;


/// Runtime status is separate from compile-time configuration: a valid URL/key
/// does not guarantee that client initialization completed successfully.
bool supabaseClientInitialized = false;
String? supabaseInitializationFailure;
