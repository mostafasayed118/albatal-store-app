import 'package:equatable/equatable.dart';

/// Parsed inbound deep link (feature-batch §5).
sealed class AppDeepLink extends Equatable {
  const AppDeepLink();

  @override
  List<Object?> get props => [];
}

/// Opens a product details page.
final class ProductDeepLink extends AppDeepLink {
  const ProductDeepLink(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

/// Opens the catalog, optionally pre-filtered by a search query.
final class CatalogDeepLink extends AppDeepLink {
  const CatalogDeepLink({this.query});

  final String? query;

  @override
  List<Object?> get props => [query];
}

/// Opens the password-recovery page. The recovery session/tokens are
/// already on the URI (Supabase appends them as a fragment) and are
/// consumed by the auth SDK before this link is routed.
final class ResetPasswordDeepLink extends AppDeepLink {
  const ResetPasswordDeepLink();
}

/// OAuth browser round-trip callback. The full URI is preserved because
/// the auth SDK exchanges the single-use `code` it carries.
final class OAuthCallbackDeepLink extends AppDeepLink {
  const OAuthCallbackDeepLink(this.uri);

  final Uri uri;

  @override
  List<Object?> get props => [uri.toString()];
}

/// Pure deep-link parser — no platform channels, fully unit-testable.
///
/// Accepted shapes:
/// - `https://<webBase.host>/product/<id>` (share/universal links)
/// - `https://<webBase.host>/catalog?q=<query>`
/// - `https://<webBase.host>/reset-password` (recovery tokens ride the
///   fragment and are consumed by the auth SDK)
/// - `https://<webBase.host>/login-callback` and
///   `<scheme>://login-callback` (OAuth round-trip, query/fragment kept)
/// - `<scheme>://product/<id>`, `<scheme>://catalog?q=<query>` and
///   `<scheme>://reset-password`
///   (custom-scheme fallbacks, e.g. `albatal://product/fabric-42`)
///
/// Everything else (foreign hosts, unknown paths, empty ids) returns
/// null so the caller ignores the link instead of navigating blind.
AppDeepLink? parseDeepLink(
  Uri uri, {
  required Uri webBase,
  String scheme = 'albatal',
}) {
  // Web links must be TLS: plain http:// is rejected outright so a
  // MITM-downgraded universal link can never steer navigation.
  final isWebHost = uri.scheme == 'https';
  final isAppScheme = uri.scheme.toLowerCase() == scheme.toLowerCase();
  if (!isWebHost && !isAppScheme) return null;
  if (isWebHost) {
    if (uri.host.isEmpty) return null;
    if (webBase.host.isNotEmpty && uri.host != webBase.host) return null;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  // A custom scheme puts the resource in the authority: albatal://product/x
  // parses with host='product', path='x' — fold the host back in.
  final segs =
      isAppScheme && uri.host.isNotEmpty ? [uri.host, ...segments] : segments;

  if (segs.length == 2 && segs.first == 'product' && segs[1].isNotEmpty) {
    // R12: the segment is already percent-decoded by [Uri], so an encoded
    // `%2F` arrives here as a literal `/` — re-encode-safe downstream
    // ([Routes.product] uses `encodeComponent`), but a decoded separator
    // must never become a trusted id. Reject it (and absurd lengths)
    // instead of navigating blind.
    final id = Uri.decodeComponent(segs[1]);
    if (id.isEmpty || id.contains('/') || id.length > 256) return null;
    return ProductDeepLink(id);
  }
  if (segs.length == 1 && segs.first == 'catalog') {
    final q = uri.queryParameters['q'];
    return CatalogDeepLink(query: (q == null || q.isEmpty) ? null : q);
  }
  if (segs.length == 1 && segs.first == 'reset-password') {
    return const ResetPasswordDeepLink();
  }
  if (segs.length == 1 && segs.first == 'login-callback') {
    return OAuthCallbackDeepLink(uri);
  }
  return null;
}
