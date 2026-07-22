import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase configuration and initialization.
///
/// Uses [flutter_dotenv] to load environment variables from `.env`.
/// The service-role key is NEVER stored in the Flutter app — only the
/// public anon key is used, which is safe for client-side usage.
class SupabaseConfig {
  const SupabaseConfig._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase with environment variables.
  ///
  /// Call this once in [main()] before [runApp].
  static Future<void> initialize() async {
    await dotenv.load();

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty) {
      throw AssertionError('SUPABASE_URL is missing from .env. '
          'Copy .env.example to .env and fill in your Supabase project values.');
    }
    if (anonKey == null || anonKey.isEmpty) {
      throw AssertionError('SUPABASE_ANON_KEY is missing from .env. '
          'Copy .env.example to .env and fill in your Supabase project values.');
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
