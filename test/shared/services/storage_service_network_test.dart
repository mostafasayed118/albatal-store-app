import 'dart:io';
import 'dart:typed_data';

import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockStorageClient extends Mock implements SupabaseStorageClient {}

class _MockStorageFileApi extends Mock implements StorageFileApi {}

void main() {
  late Directory tempDir;
  late _MockSupabaseClient client;
  late _MockStorageClient storage;
  late _MockStorageFileApi productImages;
  late _MockStorageFileApi reviewImages;
  late _MockStorageFileApi avatars;

  setUpAll(() {
    registerFallbackValue(const FileOptions());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(File('fallback'));
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_service_test');
    client = _MockSupabaseClient();
    storage = _MockStorageClient();
    productImages = _MockStorageFileApi();
    reviewImages = _MockStorageFileApi();
    avatars = _MockStorageFileApi();

    when(() => client.storage).thenReturn(storage);
    when(() => storage.from(StorageService.reviewImageBucket))
        .thenReturn(reviewImages);
    when(() => storage.from('product-images')).thenReturn(productImages);
    when(() => storage.from('avatars')).thenReturn(avatars);

    when(() => productImages.getPublicUrl(any())).thenAnswer((inv) {
      final path = inv.positionalArguments.single as String;
      if (path == 'plain') return 'https://cdn.test/plain';
      return 'https://cdn.test/storage/v1/object/public/product-images/$path';
    });
    when(() => avatars.getPublicUrl(any())).thenAnswer(
      (inv) => 'https://cdn.test/avatars/${inv.positionalArguments.single}',
    );
    when(() => reviewImages.createSignedUrl(any(), any()))
        .thenAnswer((_) async => 'https://cdn.test/signed');
    when(() => reviewImages.remove(any()))
        .thenAnswer((_) async => <FileObject>[]);
    when(() => productImages.remove(any()))
        .thenAnswer((_) async => <FileObject>[]);
    when(
      () => avatars.upload(
        any(),
        any(),
        fileOptions: any(named: 'fileOptions'),
      ),
    ).thenAnswer((_) async => 'avatars/uploaded');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('network use without an injected client fails loudly', () {
    final service = StorageService(client: null);

    expect(
      () => service.getProductImageUrl('product-images/a/b.png'),
      throwsA(isA<StateError>()),
    );
  });

  group('review images', () {
    test('buildReviewImagePath prefixes user/product and rejects bad input',
        () {
      final service = StorageService(client: client);

      final path = service.buildReviewImagePath('user-1', 'prod-1', 'a.png');
      expect(path, startsWith('user-1/prod-1/'));

      expect(
        () => service.buildReviewImagePath('', 'prod-1', 'a.png'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.buildReviewImagePath('user-1', '', 'a.png'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.buildReviewImagePath('user-1', 'prod-1', '..'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('uploadReviewImage normalizes image/jpg and uploads without upsert',
        () async {
      final service = StorageService(client: client);
      FileOptions? captured;

      when(
        () => reviewImages.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((inv) async {
        captured = inv.namedArguments[#fileOptions] as FileOptions;
        return 'ok';
      });

      final path = await service.uploadReviewImage(
        userId: 'user-1',
        productId: 'prod-1',
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'photo.jpg',
        contentType: 'image/JPG',
      );

      expect(path, startsWith('user-1/prod-1/'));
      expect(captured!.contentType, 'image/jpeg');
      expect(captured!.upsert, isFalse);
    });

    test('uploadReviewImage rejects unsupported types and bad sizes', () async {
      final service = StorageService(client: client);

      expect(
        () => service.uploadReviewImage(
          userId: 'user-1',
          productId: 'prod-1',
          bytes: Uint8List.fromList([1]),
          fileName: 'a.gif',
          contentType: 'image/gif',
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => service.uploadReviewImage(
          userId: 'user-1',
          productId: 'prod-1',
          bytes: Uint8List(0),
          fileName: 'a.png',
          contentType: 'image/png',
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => service.uploadReviewImage(
          userId: 'user-1',
          productId: 'prod-1',
          bytes: Uint8List(StorageService.maxReviewImageBytes + 1),
          fileName: 'a.png',
          contentType: 'image/png',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('signed URL and delete pass through to the review bucket', () async {
      final service = StorageService(client: client);

      expect(
        await service.createReviewImageUrl('user-1/prod-1/a.png'),
        'https://cdn.test/signed',
      );
      await service.deleteReviewImage('user-1/prod-1/a.png');

      verify(() => reviewImages.createSignedUrl('user-1/prod-1/a.png', 3600))
          .called(1);
      verify(() => reviewImages.remove(['user-1/prod-1/a.png'])).called(1);
    });
  });

  group('product images', () {
    test('getProductImageUrl resolves through the product bucket', () {
      final service = StorageService(client: client);

      expect(
        service.getProductImageUrl('product-images/a/b.png'),
        'https://cdn.test/storage/v1/object/public/product-images/'
        'product-images/a/b.png',
      );
    });

    test('getProductImageUrl asserts on traversal-shaped paths', () {
      final service = StorageService(client: client);

      expect(
        () => service.getProductImageUrl('product-images/../b.png'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('width URLs fall back to the bare public URL on this tenant', () {
      final service = StorageService(client: client);

      final renderable = service.getProductImageUrlForWidth(
        'product-images/a/b.webp',
        StorageService.gridImageWidth,
      );
      final unknownExtension = service.getProductImageUrlForWidth(
        'product-images/a/b.bin',
        StorageService.detailImageWidth,
      );
      final disallowedWidth = service.getProductImageUrlForWidth(
        'product-images/a/b.png',
        9999,
      );

      expect(renderable, contains('product-images/a/b.webp'));
      expect(unknownExtension, contains('product-images/a/b.bin'));
      expect(disallowedWidth, contains('product-images/a/b.png'));
    });

    test('getPublicUrlBase strips the storage marker, or returns the URL', () {
      final service = StorageService(client: client);

      expect(
        service.getPublicUrlBase('product-images/a/b.png'),
        'https://cdn.test',
      );
      expect(service.getPublicUrlBase('plain'), 'https://cdn.test/plain');
    });

    test('deleteProductImage removes from the product bucket', () async {
      final service = StorageService(client: client);

      await service.deleteProductImage('product-images/a/b.png');

      verify(() => productImages.remove(['product-images/a/b.png'])).called(1);
    });
  });

  group('avatars', () {
    test('getAvatarUrl resolves through the avatars bucket', () {
      final service = StorageService(client: client);

      expect(
        service.getAvatarUrl('user-1', 'avatar.png'),
        'https://cdn.test/avatars/user-1/avatar.png',
      );
    });

    test('uploadAvatar rejects invalid owners and formats', () async {
      final service = StorageService(client: client);
      final png = File('${tempDir.path}/avatar.png')..writeAsBytesSync([1]);

      expect(
        () => service.uploadAvatar(png, ''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.uploadAvatar(png, '../user'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.uploadAvatar(png, '/'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.uploadAvatar(File('${tempDir.path}/avatar'), 'user-1'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.uploadAvatar(
          File('${tempDir.path}/avatar.gif')..writeAsBytesSync([1]),
          'user-1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('uploadAvatar rejects files above the size ceiling', () async {
      final service = StorageService(client: client);
      final huge = File('${tempDir.path}/avatar.png')
        ..writeAsBytesSync(Uint8List(StorageService.avatarMaxBytes + 1));

      expect(
        () => service.uploadAvatar(huge, 'user-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('uploadAvatar writes png/webp/jpg with the right content type',
        () async {
      final service = StorageService(client: client);
      final contentTypes = <String>[];
      when(
        () => avatars.upload(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((inv) async {
        contentTypes.add(
          (inv.namedArguments[#fileOptions] as FileOptions).contentType!,
        );
        return 'ok';
      });

      for (final name in ['a.png', 'a.webp', 'a.jpg']) {
        final file = File('${tempDir.path}/$name')..writeAsBytesSync([1]);
        final url = await service.uploadAvatar(file, 'user-1');
        expect(url, contains('user-1/avatar.'));
      }

      expect(contentTypes, ['image/png', 'image/webp', 'image/jpeg']);
      verify(
        () => avatars.upload(
          'user-1/avatar.png',
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).called(1);
    });
  });
}
