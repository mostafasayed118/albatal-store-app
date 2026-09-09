import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_config.dart';
import 'supabase_secure_storage.dart';

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
      throw AssertionError('SUPABASE_URL is missing. Build with '
          '--dart-define-from-file=config/env.staging.json '
          '(or env.production.json) and fill in your Supabase project URL.');
    }
    if (anonKey.isEmpty) {
      throw AssertionError('SUPABASE_ANON_KEY is missing. Build with '
          '--dart-define-from-file=config/env.staging.json '
          '(or env.production.json) and fill in your Supabase anon key.');
    }

    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      // Encrypted session persistence (residual-P1): the Supabase auth
      // token + PKCE verifier live in the hardware-backed keystore via
      // [SecureSessionStorage]/[SecureGotrueStorage] instead of
      // cleartext SharedPreferences. The session key keeps Supabase's
      // default `sb-<project>-auth-token` format so the key namespace
      // is unchanged; a one-time migration in the adapter lifts
      // pre-existing cleartext sessions into the secure store.
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(
          persistSessionKey: _persistSessionKey(url),
        ),
        pkceAsyncStorage: SecureGotrueStorage(),
      ),
    );

    if (kDebugMode) {
      debugPrint('✅ Supabase initialized: $url');
    }
  }

  /// Current authenticated user, or null if not signed in.
  static User? get currentUser => client.auth.currentUser;

  /// Whether a user is currently authenticated.
  static bool get isAuthenticated => currentUser != null;

  /// Mirrors Supabase's default session-key format
  /// (`sb-<project-ref>-auth-token`) so the encrypted store reuses the
  /// same key namespace the stock SharedPreferences backend used.
  static String _persistSessionKey(String url) =>
      'sb-${Uri.parse(url).host.split('.').first}-auth-token';
}
