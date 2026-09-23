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
  /// Audit P1 (2026-09-19): the client is required — resolved at the
  /// composition root, never pulled from the global.
  SupabaseOAuthService({required supabase.SupabaseClient client})
      : _client = client;

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
        // Code-not-message (audit): the page classifies on `code`.
        return const Failure(AppError(kOAuthCancelled, code: kOAuthCancelled));
      }
      return const Success('ok');
    } on Exception catch (e, st) {
      // The exception is passed as `error:`, never interpolated: the
      // message can carry the redirect URL with the auth code, and the
      // logger redacts `error:` in release (audit P5). The stack stays
      // on the debug console only (Log.d is release-suppressed).
      Log.w('oauth sign-in failed', error: e, category: LogCategory.auth);
      Log.d(st.toString(), category: LogCategory.auth);
      return const Failure(
          AppError(kOAuthUnavailable, code: kOAuthUnavailable));
    }
  }
}
