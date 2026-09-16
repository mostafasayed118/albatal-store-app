import 'env_config.dart';

/// Builds the outbound share message; pure so it is testable without
/// platform channels.
String productShareMessage({required String name, required String url}) =>
    '$name — Al Batal Elite\n$url';

/// Canonical shareable URL for a product (feature-batch §5). Deep
/// links back into the app via the same host (see DeepLinkParser).
String productUrl(String productId) =>
    '${EnvConfig.webBaseUrl}/product/$productId';
