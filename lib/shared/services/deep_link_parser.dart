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

/// Pure deep-link parser — no platform channels, fully unit-testable.
///
/// Accepted shapes:
/// - `https://<webBase.host>/product/<id>` (share/universal links)
/// - `https://<webBase.host>/catalog?q=<query>`
/// - `<scheme>://product/<id>` and `<scheme>://catalog?q=<query>`
///   (custom-scheme fallbacks, e.g. `albatal://product/fabric-42`)
///
/// Everything else (foreign hosts, unknown paths, empty ids) returns
/// null so the caller ignores the link instead of navigating blind.
AppDeepLink? parseDeepLink(
  Uri uri, {
  required Uri webBase,
  String scheme = 'albatal',
}) {
  final isWebHost = uri.scheme == 'https' || uri.scheme == 'http';
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
    return ProductDeepLink(Uri.decodeComponent(segs[1]));
  }
  if (segs.length == 1 && segs.first == 'catalog') {
    final q = uri.queryParameters['q'];
    return CatalogDeepLink(query: (q == null || q.isEmpty) ? null : q);
  }
  return null;
}
