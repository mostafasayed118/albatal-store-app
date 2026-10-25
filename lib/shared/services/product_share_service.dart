import 'env_config.dart';

/// Canonical shareable URL for a product (feature-batch §5). Deep
/// links back into the app via the same host (see DeepLinkParser).
String productUrl(String productId) =>
    '${EnvConfig.webBaseUrl}/product/$productId';
