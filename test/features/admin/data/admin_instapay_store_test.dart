import 'dart:async';

import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/admin_instapay_store.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_instapay_port.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockStorageClient extends Mock implements SupabaseStorageClient {}

class _MockStorageFileApi extends Mock implements StorageFileApi {}

/// Awaitable RPC chain: the store awaits `client.rpc(...)` directly.
class _FakeRpcBuilder extends Fake implements PostgrestFilterBuilder<Object?> {
  _FakeRpcBuilder.value(this._payload) : _error = null;
  _FakeRpcBuilder.error(this._error) : _payload = null;

  final Object? _payload;
  final Object? _error;

  @override
  Future<R> then<R>(FutureOr<R> Function(Object? value) onValue,
      {Function? onError}) {
    final error = _error;
    final future = error != null
        ? Future<Object?>.error(error)
        : Future<Object?>.value(_payload);
    return future.then(onValue, onError: onError);
  }
}

T _value<T>(Result<T> result) => switch (result) {
      Success<T>(:final value) => value,
      Failure<T>() => fail('expected Success, got ${result.error.message}'),
    };

String _errorCode<T>(Result<T> result) => switch (result) {
      Success<T>() => fail('expected Failure'),
      Failure<T>(:final error) => error.code!,
    };

void main() {
  late _MockClient client;
  late _MockFunctionsClient functions;
  late _MockStorageClient storage;
  late _MockStorageFileApi proofsApi;
  late SupabaseAdminInstapay store;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = _MockClient();
    functions = _MockFunctionsClient();
    storage = _MockStorageClient();
    proofsApi = _MockStorageFileApi();
    when(() => client.functions).thenReturn(functions);
    when(() => client.storage).thenReturn(storage);
    when(() => storage.from(SupabaseAdminInstapay.bucket))
        .thenReturn(proofsApi);
    store = SupabaseAdminInstapay(client: client);
  });

  void stubList(Object? payload) {
    when(() => client.rpc<dynamic>('admin_list_instapay_proofs'))
        .thenAnswer((_) => _FakeRpcBuilder.value(payload));
  }

  void stubReviewError(FunctionException error) {
    when(() => functions.invoke('instapay-review', body: any(named: 'body')))
        .thenAnswer((_) async => throw error);
  }

  group('listPendingProofs', () {
    test('maps rows in server order and skips malformed ones', () async {
      stubList([
        {
          'proof_id': 'proof-1',
          'payment_id': 'pay-1',
          'order_id': 'order-1',
          'order_total': 150000,
          'customer_name': 'Mona',
          'reference': 'TRX-1',
          'storage_path': 'proofs/1.jpg',
          'created_at': '2026-10-25T10:00:00Z',
        },
        {'order_id': 'order-2', 'order_total': 100},
        'not a row',
        {
          'proof_id': 'proof-2',
          'order_id': 'order-2',
          'order_total': 2500,
          'customer_name': 'Ali',
          'created_at': '2026-10-25T11:00:00Z',
        },
      ]);

      final proofs = _value(await store.listPendingProofs());

      expect(proofs.map((p) => p.proofId), ['proof-1', 'proof-2'],
          reason: 'the server owns the oldest-first order');
      expect(proofs.first.total.minorUnits, 150000);
      expect(proofs.last.reference, isNull);
      verify(() => client.rpc<dynamic>('admin_list_instapay_proofs')).called(1);
    });

    test('a non-list payload degrades to an empty queue', () async {
      stubList({'unexpected': true});

      expect(_value(await store.listPendingProofs()), isEmpty);
    });

    test('an RPC rejection maps to the queue load code', () async {
      when(() => client.rpc<dynamic>('admin_list_instapay_proofs')).thenAnswer(
          (_) => _FakeRpcBuilder.error(
              const PostgrestException(message: 'permission denied')));

      expect(
        _errorCode(await store.listPendingProofs()),
        kAdminInstapayLoadFailed,
      );
    });
  });

  group('reviewProof', () {
    test('sends the trimmed note and reports success', () async {
      when(() => functions.invoke('instapay-review', body: any(named: 'body')))
          .thenAnswer((_) async => const FunctionResponse(
              status: 200, data: {'ok': true, 'code': 'approved'}));

      final result = await store.reviewProof(
        'proof-1',
        approve: true,
        note: '  verified against the bank statement  ',
      );

      expect(result, isA<Success<void>>());
      final body = verify(() => functions.invoke('instapay-review',
          body: captureAny(named: 'body'))).captured.single as Map;
      expect(body['proof_id'], 'proof-1');
      expect(body['approve'], isTrue);
      expect(body['note'], 'verified against the bank statement');
    });

    test('rejects a 2xx response that is not ok:true', () async {
      when(() => functions.invoke('instapay-review', body: any(named: 'body')))
          .thenAnswer((_) async => const FunctionResponse(
              status: 200,
              data: {'ok': false, 'code': 'proof_already_reviewed'}));

      final result = await store.reviewProof('proof-1', approve: true);

      expect(_errorCode(result), kAdminInstapayReviewFailed);
    });

    test('omits an absent/blank note', () async {
      when(() => functions.invoke('instapay-review', body: any(named: 'body')))
          .thenAnswer((_) async =>
              const FunctionResponse(status: 200, data: {'ok': true}));

      await store.reviewProof('proof-1', approve: false);
      await store.reviewProof('proof-1', approve: false, note: '   ');

      final bodies = verify(() => functions.invoke('instapay-review',
          body: captureAny(named: 'body'))).captured.cast<Map>();
      for (final body in bodies) {
        expect(body.containsKey('note'), isFalse);
        expect(body['approve'], isFalse);
      }
    });

    test('403 admin_required maps to the admin gate code', () async {
      stubReviewError(const FunctionException(
        status: 403,
        details: {'message': 'admin_required'},
      ));

      expect(
        _errorCode(await store.reviewProof('proof-1', approve: true)),
        kAdminInstapayAccessDenied,
      );
    });

    test('404 proof_not_found maps to the missing-proof code', () async {
      stubReviewError(const FunctionException(
        status: 404,
        details: {'message': 'proof_not_found'},
      ));

      expect(
        _errorCode(await store.reviewProof('proof-1', approve: true)),
        kAdminInstapayProofNotFound,
      );
    });

    test('400 proof_already_reviewed maps to the reviewed code', () async {
      stubReviewError(const FunctionException(
        status: 400,
        details: {'message': 'proof_already_reviewed'},
      ));

      expect(
        _errorCode(await store.reviewProof('proof-1', approve: false)),
        kAdminInstapayAlreadyReviewed,
      );
    });

    test('400 payment_not_pending maps to the pending code', () async {
      stubReviewError(const FunctionException(
        status: 400,
        details: {'message': 'payment_not_pending'},
      ));

      expect(
        _errorCode(await store.reviewProof('proof-1', approve: true)),
        kAdminInstapayPaymentNotPending,
      );
    });

    test('an unclassified rejection falls back to the generic review code',
        () async {
      stubReviewError(const FunctionException(
        status: 500,
        details: {'message': 'Internal error'},
      ));

      expect(
        _errorCode(await store.reviewProof('proof-1', approve: true)),
        kAdminInstapayReviewFailed,
      );
    });

    test('an untyped body falls back to the HTTP status', () async {
      stubReviewError(const FunctionException(
        status: 403,
        details: 'Forbidden',
      ));

      expect(
        _errorCode(await store.reviewProof('proof-1', approve: true)),
        kAdminInstapayAccessDenied,
      );
    });

    test('transport failures become typed failures, never throws', () async {
      when(() => functions.invoke('instapay-review', body: any(named: 'body')))
          .thenAnswer((_) async => throw Exception('connection reset'));

      final result = await store.reviewProof('proof-1', approve: true);

      expect(_errorCode(result), kAdminInstapayReviewFailed,
          reason: 'the port never throws across its boundary');
    });
  });

  group('signedProofUrl', () {
    test('mints a one-hour URL from the private bucket', () async {
      when(() => proofsApi.createSignedUrl('proofs/1.jpg', 3600))
          .thenAnswer((_) async => 'https://signed.example/proofs/1.jpg');

      final url = _value(await store.signedProofUrl('  proofs/1.jpg  '));

      expect(url, 'https://signed.example/proofs/1.jpg');
      verify(() => storage.from('instapay-proofs')).called(1);
      verify(() => proofsApi.createSignedUrl('proofs/1.jpg', 3600)).called(1);
    });

    test('an empty path fails without touching storage', () async {
      expect(
        _errorCode(await store.signedProofUrl('   ')),
        kAdminInstapayProofUrlFailed,
      );
      verifyNever(() => proofsApi.createSignedUrl(any(), any()));
    });

    test('an empty URL fails instead of rendering a broken image', () async {
      when(() => proofsApi.createSignedUrl(any(), any()))
          .thenAnswer((_) async => '   ');

      expect(
        _errorCode(await store.signedProofUrl('proofs/1.jpg')),
        kAdminInstapayProofUrlFailed,
      );
    });

    test('storage failures map to the proof URL code', () async {
      when(() => proofsApi.createSignedUrl(any(), any()))
          .thenAnswer((_) async => throw Exception('object not found'));

      expect(
        _errorCode(await store.signedProofUrl('proofs/1.jpg')),
        kAdminInstapayProofUrlFailed,
      );
    });
  });
}
