import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Downscale/re-encode gate (feature-batch §4): images below this size
/// skip compression — re-encoding small files costs CPU and can grow
/// PNGs.
const kCompressionThresholdBytes = 200 * 1024;

/// Longest edge the uploader is allowed to produce.
const kMaxUploadDimension = 1600;

/// Pure decision logic so the threshold is unit-testable without the
/// platform channel.
bool shouldCompress(int byteLength) =>
    byteLength > kCompressionThresholdBytes;

/// Upload-image compression port. Implementations must be fail-open:
/// any failure returns the original bytes — an upload must never break
/// because compression was unavailable.
abstract interface class ImageCompressor {
  Future<Uint8List> compress(Uint8List bytes);
}

/// `flutter_image_compress` implementation: JPEG quality 82, max edge
/// 1600px. Returns the input untouched when it is under the threshold
/// or when the plugin errors (unsupported format, desktop stub, …).
final class FlutterImageCompressor implements ImageCompressor {
  const FlutterImageCompressor();

  @override
  Future<Uint8List> compress(Uint8List bytes) async {
    if (!shouldCompress(bytes.length)) return bytes;
    try {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: kMaxUploadDimension,
        minHeight: kMaxUploadDimension,
        quality: 82,
        format: CompressFormat.jpeg,
      );
      // A pathological re-encode larger than the input is rejected.
      return out.lengthInBytes < bytes.lengthInBytes
          ? Uint8List.fromList(out)
          : bytes;
    } on Exception {
      return bytes;
    }
  }
}
