import 'dart:typed_data';

import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Audit 2026-09-14 P0-4, cache half.
///
/// Supabase Storage WRAPS the multipart `cacheControl` field as
/// `Cache-Control: max-age=<value>` (supabase/storage,
/// `src/storage/uploader.ts`: `cacheControl = cacheTime ? \`max-age=${cacheTime}\`
/// : 'no-cache'`). Two consequences are pinned here, because both fail
/// silently on the server — a wrong value is stored per object and cannot be
/// edited afterwards without re-uploading:
///
///  * the value must be a bare second count, so a directive string
///    (`public, max-age=…, immutable`) can never be sent; and
///  * the real upload call must actually carry it (the SDK default is `3600`).
class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockStorageClient extends Mock implements SupabaseStorageClient {}

class _MockStorageFileApi extends Mock implements StorageFileApi {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FileOptions());
    registerFallbackValue(Uint8List(0));
  });

  group('product image cache lifetime (P0-4)', () {
    test('is a bare second count, and is a year', () {
      const seconds = StorageService.productImageCacheSeconds;

      expect(
        RegExp(r'^\d+$').hasMatch(seconds),
        isTrue,
        reason: 'Supabase Storage wraps this as `max-age=<value>`; a directive '
            'string such as "public, max-age=31536000, immutable" would become '
            'the malformed header '
            '"Cache-Control: max-age=public, max-age=31536000, immutable"',
      );
      expect(
        int.parse(seconds),
        const Duration(days: 365).inSeconds,
        reason: 'one year, and above the SDK default of 3600s',
      );
    });

    test('the upload call carries it with the content type, never upserting',
        () async {
      final client = _MockSupabaseClient();
      final storage = _MockStorageClient();
      final fileApi = _MockStorageFileApi();
      final sentOptions = <FileOptions>[];

      when(() => client.storage).thenReturn(storage);
      when(() => storage.from(any())).thenReturn(fileApi);
      when(() => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: captureAny(named: 'fileOptions'),
          )).thenAnswer((inv) {
        sentOptions.add(inv.namedArguments[#fileOptions] as FileOptions);
        return Future.value('product-images/p1/x_a.jpg');
      });

      final path = await StorageService(client: client).uploadProductImage(
        'p1',
        <int>[1, 2, 3],
        'a.jpg',
        'image/jpeg',
      );

      expect(path, startsWith('product-images/p1/'));
      final options = sentOptions.single;
      expect(options.cacheControl, StorageService.productImageCacheSeconds);
      expect(options.contentType, 'image/jpeg');
      expect(options.upsert, isFalse);
    });

    test('the upload is bucketed and never writes over an existing object',
        () async {
      final client = _MockSupabaseClient();
      final storage = _MockStorageClient();
      final fileApi = _MockStorageFileApi();

      when(() => client.storage).thenReturn(storage);
      when(() => storage.from(any())).thenReturn(fileApi);
      when(() => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          )).thenAnswer((_) => Future.value('ok'));

      await StorageService(client: client).uploadProductImage(
        'p1',
        <int>[1],
        'a.jpg',
        'image/jpeg',
      );

      // The long cache lifetime is only safe because the path is fresh per
      // upload: `.from('product-images')` + upsert false. If a future edit
      // made this overwrite in place, a year-long `max-age` would start
      // serving a replaced image stale — which is the whole hazard.
      verify(() => storage.from('product-images')).called(1);
      final captured = verify(() => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: captureAny(named: 'fileOptions'),
          )).captured.single as FileOptions;
      expect(captured.upsert, isFalse);
    });
  });
}
