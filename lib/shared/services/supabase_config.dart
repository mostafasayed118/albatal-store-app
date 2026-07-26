import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_config.dart';

/// Centralized Supabase configuration and initialization.
///
/// SECURITY MODEL
/// --------------
/// The Flutter client is configured at **build time** via
/// `--dart-define-from-file=config/<env>.json`. Only the public
/// [SUPABASE_URL] and [SUPABASE_ANON_KEY] are baked into the artifact.
///
/// The service-role key is NEVER stored in the Flutter app — only the
/// public anon key is used, which is safe for client-side usage (RLS
/// remains the trust boundary).
///
/// No `.env` file is shipped as an asset, and `flutter_dotenv` is no
/// longer a dependency.
class SupabaseConfig {
  const SupabaseConfig._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase using build-time configuration.
  ///
  /// Call this once in [main()] before [runApp]. Values come from
  /// [EnvConfig] (compiled-in `--dart-define`), NOT from a runtime
  /// dotenv asset load.
  static Future<void> initialize() async {
    final url = EnvConfig.supabaseUrl;
    final anonKey = EnvConfig.supabaseAnonKey;

    if (url.isEmpty) {
      throw AssertionError(
          'SUPABASE_URL is missing. Build with '
          '--dart-define-from-file=config/env.staging.json '
          '(or env.production.json) and fill in your Supabase project URL.');
    }
    if (anonKey.isEmpty) {
      throw AssertionError(
          'SUPABASE_ANON_KEY is missing. Build with '
          '--dart-define-from-file=config/env.staging.json '
          '(or env.production.json) and fill in your Supabase anon key.');
    }

    await Supabase.initialize(url: url, publishableKey: anonKey);

    if (kDebugMode) {
      debugPrint('✅ Supabase initialized: $url');
    }
  }

  /// Current authenticated user, or null if not signed in.
  static User? get currentUser => client.auth.currentUser;

  /// Whether a user is currently authenticated.
  static bool get isAuthenticated => currentUser != null;
}
