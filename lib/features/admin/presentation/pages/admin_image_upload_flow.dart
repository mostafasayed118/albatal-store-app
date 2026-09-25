import 'package:image_picker/image_picker.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/services/image_compressor.dart';
import '../../../../shared/services/logger.dart';
import '../../../../shared/services/storage_service.dart';
import '../../domain/repositories/admin_repository.dart';

/// Picks one image for upload. Injectable so widget tests can drive
/// the flow without the platform channel.
typedef ProductImagePicker = Future<XFile?> Function(ImageSource source);

/// Post-compression size ceiling, mirroring the proof-upload guard —
/// a 1600px/82-quality re-encode should land far below this; hitting
/// it means something pathological was picked.
const maxUploadImageBytes = 5 * 1024 * 1024;

/// Extensions the product-images storage policy accepts.
const allowedUploadImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

String uploadImageContentType(String ext) => switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

/// Result of one pick→compress→upload→persist attempt.
sealed class AdminUploadOutcome {
  const AdminUploadOutcome();
}

/// User dismissed the picker — not an error.
final class AdminUploadCancelled extends AdminUploadOutcome {
  const AdminUploadCancelled();
}

final class AdminUploadSuccess extends AdminUploadOutcome {
  const AdminUploadSuccess({required this.paths});
  final List<String> paths;
}

/// [l10nKey] is a simple page-local message key; [error] is set when
/// the repository save failed (page localizes via failureText).
final class AdminUploadError extends AdminUploadOutcome {
  const AdminUploadError({this.l10nKey, this.error});
  final String? l10nKey;
  final AppError? error;
}

/// Pick → compress → validate → upload → persist gallery paths.
///
/// Extracted from `admin_image_manager_page.dart`; pure of BuildContext —
/// the page maps outcomes to localized copy and setState.
Future<AdminUploadOutcome> runAdminImageUpload({
  required String productId,
  required ProductImagePicker pickImage,
  required ImageCompressor? compressor,
  required StorageService storage,
  required AdminRepository repository,
}) async {
  final picked = await pickImage(ImageSource.gallery);
  if (picked == null) return const AdminUploadCancelled();

  var bytes = await picked.readAsBytes();
  if (bytes.isEmpty) {
    return const AdminUploadError(l10nKey: 'adminImageFileEmpty');
  }

  // §4 enforcement pass: the picker's imageQuality is only a hint
  // on some platforms.
  final effectiveCompressor = compressor ?? const FlutterImageCompressor();
  bytes = await effectiveCompressor.compress(bytes);

  final ext = picked.name.contains('.')
      ? picked.name.split('.').last.toLowerCase()
      : 'jpg';
  if (!allowedUploadImageExtensions.contains(ext)) {
    return const AdminUploadError(l10nKey: 'adminImageUnsupportedFormat');
  }
  if (bytes.length > maxUploadImageBytes) {
    return const AdminUploadError(l10nKey: 'adminImageTooLarge');
  }

  final fileName = 'upload_${DateTime.now().millisecondsSinceEpoch}.$ext';
  final storagePath = await storage.uploadProductImage(
    productId,
    bytes,
    fileName,
    uploadImageContentType(ext),
  );

  final current = await repository.getProductImagePaths(productId);
  final List<String> existing;
  switch (current) {
    case Success(:final value):
      existing = value;
    case Failure(:final error):
      await _deleteUploadedImage(storage, storagePath);
      return AdminUploadError(error: error);
  }
  final next = [...existing, storagePath];
  final saveResult = await repository.adminSetProductImages(productId, next);

  if (saveResult case Failure(:final error)) {
    await _deleteUploadedImage(storage, storagePath);
    return AdminUploadError(error: error);
  }
  return AdminUploadSuccess(paths: next);
}

Future<void> _deleteUploadedImage(
  StorageService storage,
  String storagePath,
) async {
  try {
    await storage.deleteProductImage(storagePath);
  } on Exception catch (e) {
    Log.w('orphaned product image after failed save.', error: e);
  }
}
