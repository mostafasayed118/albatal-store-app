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
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  String getProductImageUrl(String storagePath) {
    return _client.storage.from(_bucket).getPublicUrl(storagePath);
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
