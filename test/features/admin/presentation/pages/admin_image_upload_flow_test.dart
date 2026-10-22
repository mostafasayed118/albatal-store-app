import 'dart:typed_data';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_image_upload_flow.dart';
import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

/// Compression is a platform channel; the flow only needs *a* compressor.
class _IdentityCompressor implements ImageCompressor {
  @override
  Future<Uint8List> compress(Uint8List bytes) async => bytes;
}

class _Storage extends StorageService {
  _Storage({this.deleteThrows = false, this.deletedPaths})
      : super(client: null);

  final bool deleteThrows;
  final List<String>? deletedPaths;

  @override
  Future<String> uploadProductImage(
    String productId,
    List<int> bytes,
    String fileName,
    String contentType,
  ) async =>
      'product-images/$productId/$fileName';

  @override
  Future<void> deleteProductImage(String storagePath) async {
    deletedPaths?.add(storagePath);
    if (deleteThrows) throw const FileSystemExceptionStub();
  }
}

/// A plain [Exception] so the flow's `on Exception` branch is the one under
/// test (an `Error` would deliberately escape it).
class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  const bytes = [1, 2, 3, 4];

  Future<AdminUploadOutcome> run({
    required AdminRepository repository,
    required StorageService storage,
  }) =>
      runAdminImageUpload(
        productId: 'p1',
        pickImage: (_) async => XFile.fromData(
          Uint8List.fromList(bytes),
          name: 'photo.jpg',
        ),
        compressor: _IdentityCompressor(),
        storage: storage,
        repository: repository,
      );

  test('a failed gallery save deletes the uploaded orphan and reports it',
      () async {
    final repo = _MockAdminRepository();
    final deleted = <String>[];
    when(() => repo.getProductImagePaths('p1'))
        .thenAnswer((_) async => const Success(['product-images/p1/old.jpg']));
    when(() => repo.adminSetProductImages('p1', any())).thenAnswer((_) async =>
        const Failure(AppError('save failed', code: kAdminImagesSaveFailed)));

    final outcome = await run(
      repository: repo,
      storage: _Storage(deletedPaths: deleted),
    );

    expect(outcome, isA<AdminUploadError>());
    expect((outcome as AdminUploadError).error?.code, kAdminImagesSaveFailed);
    expect(deleted, hasLength(1),
        reason: 'the uploaded object must not be orphaned by a failed save');
  });

  test('a delete failure after a failed save is swallowed and still reported',
      () async {
    final repo = _MockAdminRepository();
    when(() => repo.getProductImagePaths('p1'))
        .thenAnswer((_) async => const Success(['product-images/p1/old.jpg']));
    when(() => repo.adminSetProductImages('p1', any()))
        .thenAnswer((_) async => const Failure(AppError('save failed')));

    final outcome = await run(
      repository: repo,
      storage: _Storage(deleteThrows: true),
    );

    expect(outcome, isA<AdminUploadError>(),
        reason: 'the original save failure is the one the admin must see');
    expect((outcome as AdminUploadError).error?.message, 'save failed');
  });
}
