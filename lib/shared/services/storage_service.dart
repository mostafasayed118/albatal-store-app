import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles product image uploads and URL generation.
class StorageService {
  StorageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String getProductImageUrl(String storagePath) {
    return _client.storage.from('product-images').getPublicUrl(storagePath);
  }

  String getAvatarUrl(String userId, String fileName) {
    return _client.storage.from('avatars').getPublicUrl('$userId/$fileName');
  }

  Future<String?> uploadProductImage(File file, String productId) async {
    final ext = file.path.split('.').last;
    final storagePath =
        '$productId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('product-images').upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return storagePath;
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
    await _client.storage.from('product-images').remove([storagePath]);
  }
}
