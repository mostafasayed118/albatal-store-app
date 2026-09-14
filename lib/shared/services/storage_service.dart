import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Handles product image uploads and URL generation.
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

  /// Extensions the `product-images` bucket accepts (service-layer
  /// defense in depth; the pages re-check and the server/RLS policy is
  /// the authoritative gate). Matches the admin upload allowlist.
  static const productImageAllowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  /// Client-side product-image size ceiling (5 MB, mirrors the avatar
  /// path). Oversized files are rejected before any bytes leave the
  /// device.
  static const productImageMaxBytes = 5 * 1024 * 1024;

  Future<String> uploadProductImage(
    String productId,
    List<int> bytes,
    String fileName,
    String contentType,
  ) async {
    // Validate BEFORE touching the network client so bad input fails
    // closed with [ArgumentError] (unit-testable without Supabase init).
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!productImageAllowedExtensions.contains(ext)) {
      throw ArgumentError('unsupported product image format');
    }
    if (bytes.length > productImageMaxBytes) {
      throw ArgumentError('product image too large');
    }
    final path = buildProductImagePath(productId, fileName);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await _client.storage.from(_bucket).uploadBinary(
          path,
          data,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  String getProductImageUrl(String storagePath, {int? width}) {
    // Width-bounded requests hit the Supabase image-transform render
    // endpoint so a 420px grid thumbnail downloads a ~420px JPEG instead
    // of the full-resolution original (audit 2026-09-14 perf). A null
    // [width] keeps the untransformed full-res URL for the detail/zoom
    // path.
    return _client.storage.from(_bucket).getPublicUrl(
          storagePath,
          transform: width == null
              ? null
              : TransformOptions(
                  width: width,
                  resize: ResizeMode.contain,
                  quality: 80,
                ),
        );
  }

  /// Upgrades an already-built `product-images` public URL to the
  /// width-bounded render variant ([getProductImageUrl] with [width]).
  ///
  /// Widgets hold URL strings (not storage paths), so thumbnails use
  /// this to request a server-resized download that matches their
  /// `memCacheWidth` decode budget instead of the full-res original
  /// (audit 2026-09-14 perf). URLs that are not `product-images`
  /// public objects (assets, third-party hosts, the zoom path) pass
  /// through unchanged.
  static String transformPublicUrl(String url, {required int width}) {
    const marker = '/object/public/$_bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return url;
    final path = url.substring(i + marker.length);
    if (path.isEmpty) return url;
    return '${url.substring(0, i)}/render/image/public/$_bucket/$path'
        '?width=$width&resize=contain&quality=80';
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
