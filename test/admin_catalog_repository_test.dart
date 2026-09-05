import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:al_batal_elite/features/admin/data/supabase_admin_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder(this._value);
  final T _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future.value(_value).catchError(onError, test: test);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return Future.value(_value).whenComplete(action);
  }

  @override
  Stream<T> asStream() => Future.value(_value).asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return Future.value(_value).timeout(timeLimit, onTimeout: onTimeout);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('adminUpsertProduct calls rpc with correct params', () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('admin_upsert_product', params: any(named: 'params')))
        .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>('new-uuid'));
    final repo = SupabaseAdminRepository(client: client);
    final id = await repo.adminUpsertProduct(
      name: 'Thobe',
      slug: 'thobe',
      description: 'd',
      composition: 'cotton',
      categoryId: 'cat-1',
      basePrice: 100,
      isActive: true,
    );
    verify(() => client.rpc('admin_upsert_product', params: {
          'p_id': null,
          'p_name': 'Thobe',
          'p_slug': 'thobe',
          'p_description': 'd',
          'p_composition': 'cotton',
          'p_category_id': 'cat-1',
          'p_base_price': 100,
          'p_is_active': true,
        })).called(1);
    expect(id, 'new-uuid');
  });
}
