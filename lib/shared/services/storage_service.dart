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

  Future<String?> uploadAvatar(File file, String userId) async {
    final ext = file.path.split('.').last;
    final storagePath = '$userId/avatar.$ext';

    await _client.storage.from('avatars').upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return getAvatarUrl(userId, 'avatar.$ext');
  }

  Future<void> deleteProductImage(String storagePath) async {
    await _client.storage.from(_bucket).remove([storagePath]);
  }
}
