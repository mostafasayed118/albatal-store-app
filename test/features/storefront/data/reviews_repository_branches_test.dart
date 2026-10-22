import 'dart:async';
import 'dart:typed_data';

import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/review_mapper.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _MockStorageClient extends Mock implements SupabaseStorageClient {}

class _MockFileApi extends Mock implements StorageFileApi {}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this.chain);

  final _FakeRowsChain chain;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) => chain;
}

class _FakeRowsChain extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeRowsChain(this.rows, {this.error});

  final List<Map<String, dynamic>> rows;
  final Object? error;
  final List<String> calls = [];

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    calls.add('eq:$column');
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    calls.add('order:$column');
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) {
    calls.add('limit:$count');
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) {
    if (error != null) {
      return Future<PostgrestList>.error(error!)
          .then(onValue, onError: onError);
    }
    return Future<PostgrestList>.value(rows).then(onValue, onError: onError);
  }
}

class _FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  _FakeRpc(this.payload);

  final Object? payload;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) =>
      Future<dynamic>.value(payload).then(onValue, onError: onError);
}

Map<String, dynamic> _row({
  String id = 'r1',
  String productId = 'p1',
  int rating = 5,
  String text = 'Lovely fabric',
  String createdAt = '2026-09-01T10:00:00Z',
  String? photoUrl,
}) =>
    {
      'id': id,
      'product_id': productId,
      'rating': rating,
      'text': text,
      'created_at': createdAt,
      'author_name': 'Nour',
      if (photoUrl != null) 'photo_url': photoUrl,
    };

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
    registerFallbackValue(<String>[]);
  });

  group('SupabaseReviewsRepository.fetchForProduct', () {
    late _MockClient client;
    late _MockStorageClient storageClient;
    late _MockFileApi fileApi;

    void stubReviewImages() {
      when(() => client.storage).thenReturn(storageClient);
      when(() => storageClient.from('review-images')).thenReturn(fileApi);
    }

    setUp(() {
      client = _MockClient();
      storageClient = _MockStorageClient();
      fileApi = _MockFileApi();
      stubReviewImages();
    });

    test('maps valid rows, skips malformed, and signs only relative photos',
        () async {
      final chain = _FakeRowsChain([
        _row(id: 'r1', photoUrl: 'https://cdn.example/approved.jpg'),
        _row(id: 'r2', photoUrl: 'u1/p1/photo.jpg'),
        _row(id: 'r3', photoUrl: ''),
        _row(id: 'bad-rating', rating: 9),
        _row(id: 'bad-date', createdAt: 'not-a-date'),
        <String, dynamic>{},
      ]);
      when(() => client.from('product_reviews_public'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));
      when(() => fileApi.createSignedUrl(any(), 3600))
          .thenAnswer((_) async => 'https://signed.example/r2.jpg');

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.fetchForProduct('p1');

      expect(result, isA<Success<List<ProductReview>>>());
      final reviews = (result as Success<List<ProductReview>>).value;
      expect(reviews.map((r) => r.id), ['r1', 'r2', 'r3']);
      // Absolute URLs pass through untouched.
      expect(reviews[0].photoUrl, 'https://cdn.example/approved.jpg');
      // Relative storage paths are exchanged for a signed URL.
      expect(reviews[1].photoUrl, 'https://signed.example/r2.jpg');
      // Empty photo degrades to no photo, not an empty string.
      expect(reviews[2].photoUrl, isNull);

      expect(chain.calls, contains('eq:product_id'));
      expect(chain.calls, contains('order:created_at'));
      expect(chain.calls, contains('limit:50'));
      // Only the one relative path asked for a signature.
      verify(() => fileApi.createSignedUrl('u1/p1/photo.jpg', 3600)).called(1);
      verifyNever(() =>
          fileApi.createSignedUrl('https://cdn.example/approved.jpg', 3600));
    });

    test('empty signature strips the photo instead of surfacing a dead URL',
        () async {
      final chain = _FakeRowsChain([_row(photoUrl: 'u1/p1/photo.jpg')]);
      when(() => client.from('product_reviews_public'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));
      when(() => fileApi.createSignedUrl(any(), 3600))
          .thenAnswer((_) async => '');

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.fetchForProduct('p1');

      final reviews = (result as Success<List<ProductReview>>).value;
      expect(reviews.single.photoUrl, isNull);
    });

    test('signing failure strips the photo and keeps the review', () async {
      final chain = _FakeRowsChain([_row(photoUrl: 'u1/p1/photo.jpg')]);
      when(() => client.from('product_reviews_public'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));
      when(() => fileApi.createSignedUrl(any(), 3600))
          .thenThrow(Exception('storage down'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.fetchForProduct('p1');

      expect(result, isA<Success<List<ProductReview>>>());
      expect((result as Success<List<ProductReview>>).value.single.photoUrl,
          isNull);
    });

    test('Postgrest failure degrades to review_unavailable', () async {
      final chain = _FakeRowsChain(
        const [],
        error: const PostgrestException(
            message: 'relation missing', code: '42P01'),
      );
      when(() => client.from('product_reviews_public'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.fetchForProduct('p1');

      expect(result, isA<Failure<List<ProductReview>>>());
      expect((result as Failure).error.code, kReviewUnavailable);
    });

    test('transport failure degrades to review_unavailable', () async {
      final chain = _FakeRowsChain(const [], error: Exception('offline'));
      when(() => client.from('product_reviews_public'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.fetchForProduct('p1');

      expect(result, isA<Failure<List<ProductReview>>>());
      expect((result as Failure).error.code, kReviewUnavailable);
    });
  });

  group('SupabaseReviewsRepository.submit', () {
    late _MockClient client;
    late _MockAuth auth;
    late _MockUser user;
    late _MockStorageClient storageClient;
    late _MockFileApi fileApi;

    setUp(() {
      client = _MockClient();
      auth = _MockAuth();
      user = _MockUser();
      storageClient = _MockStorageClient();
      fileApi = _MockFileApi();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('u1');
      when(() => client.storage).thenReturn(storageClient);
      when(() => storageClient.from('review-images')).thenReturn(fileApi);
    });

    test('rating above the allowed range fails before any network call',
        () async {
      final repo = SupabaseReviewsRepository(client: client);

      final result = await repo.submit(productId: 'p1', rating: 6, text: 'ok');

      expect((result as Failure).error.code, kReviewInvalid);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
      verifyNever(() => user.id);
    });

    test('oversized photo fails before auth or upload', () async {
      final repo = SupabaseReviewsRepository(client: client);

      final result = await repo.submit(
        productId: 'p1',
        rating: 5,
        text: 'ok',
        photoBytes: Uint8List(maxReviewPhotoBytes + 1),
      );

      expect((result as Failure).error.code, kReviewInvalid);
      verifyNever(() => client.auth);
      verifyNever(() => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ));
    });

    test('a missing session fails as unavailable', () async {
      when(() => auth.currentUser).thenReturn(null);
      final repo = SupabaseReviewsRepository(client: client);

      final result = await repo.submit(productId: 'p1', rating: 5, text: 'ok');

      expect((result as Failure).error.code, kReviewUnavailable);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('uploads the photo, submits, and signs the returned relative path',
        () async {
      when(() => fileApi.uploadBinary(
                any(),
                any(),
                fileOptions: any(named: 'fileOptions'),
              ))
          .thenAnswer((invocation) async =>
              invocation.positionalArguments[0] as String);
      when(() => fileApi.createSignedUrl(any(), 3600))
          .thenAnswer((_) async => 'https://signed.example/new.jpg');
      final params = <String, dynamic>{};
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenAnswer((invocation) {
        params
            .addAll(invocation.namedArguments[#params] as Map<String, dynamic>);
        return _FakeRpc(_row(rating: 4, photoUrl: 'u1/p1/uploaded.jpg'));
      });

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(
        productId: 'p1',
        rating: 4,
        text: '  Nice  ',
        photoBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isA<Success<ProductReview>>());
      final review = (result as Success<ProductReview>).value;
      expect(review.rating, 4);
      expect(review.photoUrl, 'https://signed.example/new.jpg');
      expect(params['p_text'], 'Nice');
      expect(params['p_photo_path'], startsWith('u1/p1/'));
      verify(() => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          )).called(1);
    });

    test('empty photo list skips upload and submits without a path', () async {
      final params = <String, dynamic>{};
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenAnswer((invocation) {
        params
            .addAll(invocation.namedArguments[#params] as Map<String, dynamic>);
        return _FakeRpc(_row());
      });

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo
          .submit(productId: 'p1', rating: 5, text: 'ok', photoBytes: const []);

      expect(result, isA<Success<ProductReview>>());
      expect(params['p_photo_path'], isNull);
      verifyNever(() => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          ));
    });

    test('an unusable review row removes the uploaded photo', () async {
      when(() => fileApi.uploadBinary(
                any(),
                any(),
                fileOptions: any(named: 'fileOptions'),
              ))
          .thenAnswer((invocation) async =>
              invocation.positionalArguments[0] as String);
      when(() => fileApi.remove(any())).thenAnswer((_) async => const []);
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenAnswer((_) => _FakeRpc(<String, dynamic>{}));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(
        productId: 'p1',
        rating: 5,
        text: 'ok',
        photoBytes: Uint8List.fromList([1]),
      );

      expect((result as Failure).error.code, kReviewInvalid);
      verify(() => fileApi.remove(any())).called(1);
    });

    test('42501 maps to buy-required and removes the uploaded photo', () async {
      when(() => fileApi.uploadBinary(
                any(),
                any(),
                fileOptions: any(named: 'fileOptions'),
              ))
          .thenAnswer((invocation) async =>
              invocation.positionalArguments[0] as String);
      when(() => fileApi.remove(any())).thenAnswer((_) async => const []);
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenThrow(
              const PostgrestException(message: 'denied', code: '42501'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(
        productId: 'p1',
        rating: 5,
        text: 'ok',
        photoBytes: Uint8List.fromList([1]),
      );

      expect((result as Failure).error.code, kReviewBuyRequired);
      verify(() => fileApi.remove(any())).called(1);
    });

    test('403 maps to buy-required', () async {
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenThrow(const PostgrestException(message: 'denied', code: '403'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(productId: 'p1', rating: 5, text: 'ok');

      expect((result as Failure).error.code, kReviewBuyRequired);
    });

    test('purchase wording maps to buy-required', () async {
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenThrow(const PostgrestException(
              message: 'You must have a verified PURCHASE'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(productId: 'p1', rating: 5, text: 'ok');

      expect((result as Failure).error.code, kReviewBuyRequired);
    });

    test('buy wording maps to buy-required', () async {
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenThrow(
              const PostgrestException(message: 'please buy this product'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(productId: 'p1', rating: 5, text: 'ok');

      expect((result as Failure).error.code, kReviewBuyRequired);
    });

    test('an unrelated Postgrest failure maps to unavailable', () async {
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenThrow(const PostgrestException(message: 'rate limited'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(productId: 'p1', rating: 5, text: 'ok');

      expect((result as Failure).error.code, kReviewUnavailable);
    });

    test('a cleanup failure is swallowed and the mapped failure is returned',
        () async {
      when(() => fileApi.uploadBinary(
                any(),
                any(),
                fileOptions: any(named: 'fileOptions'),
              ))
          .thenAnswer((invocation) async =>
              invocation.positionalArguments[0] as String);
      when(() => fileApi.remove(any())).thenThrow(Exception('delete failed'));
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenThrow(
              const PostgrestException(message: 'denied', code: '42501'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(
        productId: 'p1',
        rating: 5,
        text: 'ok',
        photoBytes: Uint8List.fromList([1]),
      );

      expect((result as Failure).error.code, kReviewBuyRequired);
    });

    test('a generic failure removes the uploaded photo and returns unavailable',
        () async {
      when(() => fileApi.uploadBinary(
                any(),
                any(),
                fileOptions: any(named: 'fileOptions'),
              ))
          .thenAnswer((invocation) async =>
              invocation.positionalArguments[0] as String);
      when(() => fileApi.remove(any())).thenAnswer((_) async => const []);
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenThrow(Exception('socket closed'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(
        productId: 'p1',
        rating: 5,
        text: 'ok',
        photoBytes: Uint8List.fromList([1]),
      );

      expect((result as Failure).error.code, kReviewUnavailable);
      verify(() => fileApi.remove(any())).called(1);
    });

    test('an upload failure returns unavailable without calling the RPC',
        () async {
      when(() => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          )).thenThrow(Exception('upload rejected'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(
        productId: 'p1',
        rating: 5,
        text: 'ok',
        photoBytes: Uint8List.fromList([1]),
      );

      expect((result as Failure).error.code, kReviewUnavailable);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });
  });
}
