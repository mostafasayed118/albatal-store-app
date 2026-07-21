import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for dev/staging/production.
///
/// SECURITY NOTE: this class intentionally does NOT expose
/// any Paymob server secrets. Payment provider keys
/// (`PAYMOB_API_KEY`, `PAYMOB_INTEGRATION_ID`,
/// `PAYMOB_HMAC_SECRET`) live ONLY in Edge Function
/// environment variables and must never be shipped to the
/// Flutter client.
class EnvConfig {
  const EnvConfig._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get sentryDsn => dotenv.env['SENTRY_DSN'] ?? '';

  /// Current environment name.
  static String get environment => kDebugMode ? 'development' : 'production';

  /// Whether we're in development mode.
  static bool get isDevelopment => kDebugMode;

  /// Validate that all required env vars are present.
  static List<String> validate() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    return missing;
  }
}
