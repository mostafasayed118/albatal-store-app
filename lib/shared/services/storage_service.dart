import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Handles product image uploads and URL generation.
///
/// PATH CONTRACT: [buildProductImagePath] returns a path that is ALREADY
/// prefixed with the bucket name (`product-images/<productId>/<uuid>_<file>`)
/// and is stored verbatim in `product_images.storage_path`. [getProductImageUrl]
/// therefore resolves those stored paths through the same bucket. The prefix
/// is redundant with `.from(_bucket)` — changing the shape now would
/// invalidate every path already persisted in the database, so it is kept and
/// documented rather than "fixed". `test/shared/services/storage_service_prefix_test.dart`
/// pins the contract.
class StorageService {
  StorageService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const _bucket = 'product-images';

  String buildProductImagePath(String productId, String fileName) {
    if (productId.isEmpty) throw ArgumentError('productId empty');
    if (fileName.contains('..')) throw ArgumentError('invalid fileName');
    final sanitized = fileName.split('/').last.split('\\').last;
    if (sanitized.contains('..')) throw ArgumentError('invalid fileName');
    if (sanitized.isEmpty) throw ArgumentError('fileName empty');
    return '$_bucket/$productId/${const Uuid().v4()}_$sanitized';
  }

  Future<String> uploadProductImage(
    String productId,
    List<int> bytes,
    String fileName,
    String contentType,
  ) async {
    final path = buildProductImagePath(productId, fileName);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await _client.storage.from(_bucket).uploadBinary(
          path,
          data,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: productImageCacheSeconds,
            upsert: false,
          ),
        );
    return path;
  }

  String getProductImageUrl(String storagePath) {
    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  /// Render-URL width budget for the list/card surfaces (product grid,
  /// flash-sale row, wishlist/cart thumbnails) — audit 2026-09-14 P0-4.
  static const gridImageWidth = 420;

  /// Render-URL width budget for the detail gallery and the full-screen
  /// zoom view, which share one image list (audit 2026-09-14 P0-4).
  static const detailImageWidth = 720;

  /// Cache lifetime stamped on an uploaded product image, in **seconds** — one
  /// year (audit 2026-09-14 P0-4).
  ///
  /// This value is sent as the multipart `cacheControl` field, and Supabase
  /// Storage WRAPS that field: its uploader does
  /// `cacheControl = cacheTime ? `max-age=${cacheTime}` : 'no-cache'`
  /// (supabase/storage, `src/storage/uploader.ts`). So this field can express
  /// *only* a duration — a directive string like
  /// `public, max-age=31536000, immutable` would be wrapped into the malformed
  /// `max-age=public, max-age=31536000, immutable`. `immutable` is therefore
  /// NOT expressible through the SDK, and the decision here is the duration.
  ///
  /// A year is safe because the object behind a URL can never change:
  /// [buildProductImagePath] mints a fresh UUID per upload and uploads are
  /// never upserted, so replacing an image writes a NEW path (the old one is
  /// deleted, and any cached copy of it is dead by construction). The SDK
  /// default is `3600` (one hour).
  ///
  /// Must stay digits-only — a directive would silently produce a broken
  /// header, so `storage_service_cache_control_test.dart` pins both the shape
  /// and the value actually put on the wire.
  static const productImageCacheSeconds = '31536000';

  /// Width-bounded render URL for a product image (audit 2026-09-14 P0-4).
  ///
  /// Serves the downsized variant instead of the full upload. Pass one of the
  /// named budgets on this class rather than a literal: [gridImageWidth] for
  /// list/card surfaces, [detailImageWidth] for the detail gallery — which the
  /// full-screen zoom view shares, so a product's photos are fetched once.
  /// Falls back to the bare public URL when the path has no usable image
  /// extension (fail-open, same posture as `ImageCompressor`) so a bad path
  /// never breaks the image pipeline. Widths are allowlisted — arbitrary
  /// caller input can never reach the URL builder.
  String getProductImageUrlForWidth(String storagePath, int width) {
    const allowed = <int>{180, 420, 720, 1080};
    final w = allowed.contains(width) ? width : 720;
    final lower = storagePath.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot >= 0 ? lower.substring(dot + 1) : '';
    const renderable = <String>{'jpg', 'jpeg', 'png', 'webp'};
    if (!renderable.contains(ext)) {
      return getProductImageUrl(storagePath);
    }
    final base = getPublicUrlBase(storagePath);
    return '$base/storage/v1/render/image/public/$_bucket/'
        '$storagePath?width=$w&quality=70&resize=contain';
  }

  /// Public-URL base (scheme + host) for the current Supabase project,
  /// derived from the bare public URL so per-environment hosts keep
  /// working without a new config value.
  @visibleForTesting
  String getPublicUrlBase(String storagePath) {
    final bare = getProductImageUrl(storagePath);
    final marker = '/storage/v1/object/public/$_bucket/';
    final idx = bare.indexOf(marker);
    return idx >= 0 ? bare.substring(0, idx) : bare;
  }

  String getAvatarUrl(String userId, String fileName) {
    return _client.storage.from('avatars').getPublicUrl('$userId/$fileName');
  }

  /// Extensions the `avatars` bucket accepts (client-side pre-check; the
  /// server/RLS policy is the authoritative gate).
  static const avatarAllowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  /// Client-side avatar size ceiling (5 MB). Oversized files are rejected
  /// before any bytes leave the device.
  static const avatarMaxBytes = 5 * 1024 * 1024;

  static String _avatarContentType(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  Future<String?> uploadAvatar(File file, String userId) async {
    // Validate BEFORE touching the network client so bad input fails
    // closed with [ArgumentError] (unit-testable without Supabase init).
    if (userId.isEmpty || userId.contains('..')) {
      throw ArgumentError('invalid userId');
    }
    final userSegment = userId.split('/').last.split('\\').last;
    if (userSegment.isEmpty || userSegment.contains('..')) {
      throw ArgumentError('invalid userId');
    }
    final rawExt = file.path.split('.').last.toLowerCase();
    if (file.path.split('.').length < 2 ||
        !avatarAllowedExtensions.contains(rawExt)) {
      throw ArgumentError('unsupported avatar format');
    }
    if (await file.length() > avatarMaxBytes) {
      throw ArgumentError('avatar too large');
    }
    final storagePath = '$userSegment/avatar.$rawExt';

    // Never upsert: an avatar row is immutable-once-written; a repeat
    // upload surfaces as a storage error instead of silently replacing
    // the previous file (same fail-closed posture as product images).
    // Deliberately keeps the SDK's one-hour default lifetime (unlike
    // [uploadProductImage]): the avatar path is FIXED per user, so a delete
    // followed by a re-upload reuses it, and a year-long cached copy would
    // keep showing the customer's previous photo.
    await _client.storage.from('avatars').upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            contentType: _avatarContentType(rawExt),
            upsert: false,
          ),
        );

    return getAvatarUrl(userSegment, 'avatar.$rawExt');
  }

  Future<void> deleteProductImage(String storagePath) async {
    await _client.storage.from(_bucket).remove([storagePath]);
  }
}
