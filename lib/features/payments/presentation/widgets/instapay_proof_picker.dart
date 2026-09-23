import 'package:image_picker/image_picker.dart';

import '../../../../shared/services/image_compressor.dart';
import '../../../../shared/services/logger.dart';

/// A picked proof screenshot: compressed bytes plus the validated extension
/// and the original file name for the confirmation line.
typedef ProofScreenshot = ({List<int> bytes, String ext, String fileName});

/// Gallery pick + §4 compression + size/type validation for an InstaPay
/// proof screenshot.
///
/// Returns the usable pick, or null when the user cancels, the bytes are
/// empty, or a validation check fails. Failures report through [onError]
/// with an already-localized message supplied by the caller
/// ([emptyError], [tooLargeError], [typeNotAllowedError]) — localization
/// stays with the page, enforcement here.
///
/// Extension allowlist and size bound mirror the server guards
/// (client-side pre-check only; the edge function re-validates, and the
/// magic-byte check stays server-side). A null [compressor] (pre-DI tests)
/// falls back to the raw picker bytes; the server guard still bounds the
/// upload. Throws from the picker/compressor are caught and reported, never
/// propagated — a failed pick must not crash the route.
Future<ProofScreenshot?> pickInstapayProofScreenshot({
  required ImagePicker picker,
  required ImageCompressor? compressor,
  required int maxBytes,
  required Set<String> allowedExtensions,
  required String emptyError,
  required String tooLargeError,
  required String typeNotAllowedError,
  required void Function(String message) onError,
}) async {
  try {
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (xfile == null) return null;
    var bytes = await xfile.readAsBytes();
    if (bytes.isEmpty) {
      onError(emptyError);
      return null;
    }
    // §4: picker imageQuality is only a hint on some platforms; this
    // is the enforcement pass before the size check and upload.
    if (compressor != null) bytes = await compressor.compress(bytes);
    if (bytes.length > maxBytes) {
      onError(tooLargeError);
      return null;
    }
    final ext = xfile.name.contains('.')
        ? xfile.name.split('.').last.toLowerCase()
        : 'jpg';
    if (!allowedExtensions.contains(ext)) {
      onError(typeNotAllowedError);
      return null;
    }
    return (bytes: bytes, ext: ext, fileName: xfile.name);
  } catch (e) {
    Log.w('InstaPay screenshot pick failed.', error: e);
    onError(emptyError);
    return null;
  }
}
