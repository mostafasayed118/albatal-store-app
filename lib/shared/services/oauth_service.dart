import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/error/app_error.dart';
import '../../core/error/result.dart';
import 'logger.dart';

/// OAuth provider selector (feature-batch §15).
enum OAuthProvider { google, apple }

/// Machine-readable outcome codes for the sign-in page.
const kOAuthUnavailable = 'oauth_unavailable';
const kOAuthCancelled = 'oauth_cancelled';

/// OAuth sign-in port (browser-based flow via Supabase Auth).
abstract interface class OAuthService {
  /// Starts the OAuth flow. Returns a stable machine code on failure
  /// (`oauth_unavailable`, `oauth_cancelled`); success completes after
  /// the browser round-trip when Supabase redirects back into the app.
  Future<Result<String>> signIn(OAuthProvider provider);
}

/// Supabase implementation. The providers themselves must be enabled in
/// the Supabase dashboard (Google/Apple credentials — owner/infra task);
/// when they are not, the auth call throws and this maps it to
/// `oauth_unavailable` so the sign-in page shows a graceful message.
class SupabaseOAuthService implements OAuthService {
  SupabaseOAuthService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  Future<Result<String>> signIn(OAuthProvider provider) async {
    final native = switch (provider) {
      OAuthProvider.google => supabase.OAuthProvider.google,
      OAuthProvider.apple => supabase.OAuthProvider.apple,
    };
    try {
      final res = await _client.auth.signInWithOAuth(native);
      if (!res) {
        return const Failure(AppError(kOAuthCancelled));
      }
      return const Success('ok');
    } on Exception catch (e, st) {
      Log.w('oauth sign-in failed: $e');
      Log.d(st.toString());
      return const Failure(AppError(kOAuthUnavailable));
    }
  }
}
