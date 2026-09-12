import 'package:share_plus/share_plus.dart';

import 'env_config.dart';

/// Builds the outbound share message; pure so it is testable without
/// platform channels.
String productShareMessage({required String name, required String url}) =>
    '$name — Al Batal Elite\n$url';

/// Canonical shareable URL for a product (feature-batch §5). Deep
/// links back into the app via the same host (see DeepLinkParser).
String productUrl(String productId) =>
    '${EnvConfig.webBaseUrl}/product/$productId';

abstract interface class ProductShareService {
  /// Opens the platform share sheet with [message].
  Future<void> shareText(String message);
}

/// `share_plus` implementation. Cancelling the share sheet is a user
/// decision, not an error — failures are swallowed, never rethrown.
final class SharePlusProductShareService implements ProductShareService {
  const SharePlusProductShareService();

  @override
  Future<void> shareText(String message) async {
    try {
      await SharePlus.instance.share(ShareParams(text: message));
    } on Exception {
      // Share unavailable or dismissed — nothing to recover.
    }
  }
}
