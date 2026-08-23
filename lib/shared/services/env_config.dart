import 'package:flutter/foundation.dart';

/// Environment configuration for dev/staging/production.
///
/// SECURITY MODEL
/// --------------
/// Configuration is injected at **build time** via
/// `--dart-define-from-file=config/<env>.json`. Values are baked into the
/// compiled artifact by the Dart compiler; nothing is read from disk or an
/// asset bundle at runtime.
///
/// ALLOWED client-side values (public, safe to ship):
///   - SUPABASE_URL
///   - SUPABASE_ANON_KEY
///   - SENTRY_DSN  (only when Sentry is approved and added to pubspec)
///
/// NEVER shipped to the Flutter client (server-only secrets):
///   - PAYMOB_API_KEY
///   - PAYMOB_INTEGRATION_ID
///   - PAYMOB_HMAC_SECRET
///   - PAYMOB_IFRAME_ID
///   - SUPABASE_SERVICE_ROLE_KEY
///   - SCHEDULER_SECRET
///   - any Edge Function secret
///
/// Those server secrets live ONLY in Supabase Edge Function environment
/// variables / the Supabase dashboard and are never referenced from Dart.
class EnvConfig {
  const EnvConfig._();

  /// Public Supabase project URL. Safe to ship (anon access is enforced by RLS).
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Public anon key. Safe to ship — RLS is the trust boundary, not the key.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Sentry DSN. Public identifier; only set when Sentry is approved.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Current environment name.
  static String get environment => kDebugMode ? 'development' : 'production';

  /// Whether we're in development mode.
  static bool get isDevelopment => kDebugMode;

  /// Validate that all required client env vars are present.
  ///
  /// Returns a list of missing variable names. An empty list means the
  /// build was configured correctly via `--dart-define-from-file`.
  static List<String> validate() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    return missing;
  }
}
