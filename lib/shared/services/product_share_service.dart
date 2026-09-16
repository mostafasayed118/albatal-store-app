import 'dart:io';

import 'package:path_provider/path_provider.dart';
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

/// Opens the platform share sheet with arbitrary text.
///
/// Deliberately named for the capability, not a caller: the §5 product
/// share and the §14 admin orders CSV export both route through here,
/// because what this wraps (`SharePlus.instance.share`) is not
/// product-specific. The product-flavoured copy and URL helpers live
/// above.
abstract interface class ShareService {
  /// Opens the platform share sheet with [message].
  Future<void> shareText(String message);

  /// Shares [content] as a real file attachment named [fileName].
  ///
  /// Used where pasting text into a message would not do — a CSV needs to
  /// arrive as a file the recipient can open in a spreadsheet.
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  });
}

/// `share_plus` implementation. Cancelling the share sheet is a user
/// decision, not an error — failures are swallowed, never rethrown.
final class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareText(String message) async {
    try {
      await SharePlus.instance.share(ShareParams(text: message));
    } on Exception {
      // Share unavailable or dismissed — nothing to recover.
    }
  }

  @override
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    try {
      // The bytes are written on every export rather than cached: the
      // payload is per-view, and the OS reclaims the temp dir itself.
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
      );
    } on UnimplementedError {
      // share_plus cannot share files on Linux; the app targets mobile.
    } on Exception {
      // No writable temp dir, or the sheet was dismissed — nothing to
      // recover.
    }
  }
}
