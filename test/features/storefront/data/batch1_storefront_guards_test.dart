import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/features/storefront/data/review_mapper.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/shared/services/analytics_service.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _FailingWishlistRepo implements WishlistRepository {
  @override
  Future<Result<Set<String>>> readWishlist() async =>
      const Failure(AppError('nope', code: 'wishlist_load_failed'));

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async =>
      const Failure(AppError('nope', code: 'wishlist_save_failed'));
}

/// Sink that fails the first batch, then succeeds — proves flush retries
/// instead of dropping funnel events.
class _FlakySink implements AnalyticsSink {
  _FlakySink(this.sent);

  final List<String> sent;
  var _calls = 0;

  @override
  Future<void> send(String name, Map<String, dynamic> props) =>
      sendBatch([(name: name, props: props)]);

  @override
  Future<void> sendBatch(
      List<({String name, Map<String, dynamic> props})> events) async {
    _calls++;
    if (_calls == 1) throw StateError('network down');
    sent.addAll(events.map((e) => e.name));
  }
}

/// Batch 1 regression guards: fail-soft casts, photo cap, analytics
/// re-queue, and coded wishlist errors.
void main() {
  group('Batch 1 — storefront fail-soft casts', () {
    test('mistyped sell_by_length degrades to false instead of throwing', () {
      for (final bad in ['yes', 1, 0, null]) {
        final product = ProductCodec.fromRow(
          {
            'id': 'p1',
            'name': 'Cotton',
            'base_price': 1000,
            'sell_by_length': bad
          },
          const [],
          storageService: StorageService(client: null),
        )!;
        expect(product.sellByLength, isFalse, reason: 'input: $bad');
      }
    });

    test('mistyped cached sellByLength degrades to false', () {
      final decoded = ProductCodec.decode({
        'id': 'p1',
        'name': 'Cotton',
        'price': 1000,
        'sellByLength': 'yes',
      })!;
      expect(decoded.sellByLength, isFalse);
    });
  });

  group('Batch 1 — review photo cap', () {
    test('oversized photo fails with invalid code, no network call', () async {
      final client = _MockSupabaseClient();
      final repo = SupabaseReviewsRepository(client: client);
      final big = List.filled(maxReviewPhotoBytes + 1, 0);

      final result = await repo.submit(
          productId: 'p1', rating: 5, text: 'ok', photoBytes: big);

      expect(result, isA<Failure>());
      expect((result as Failure).error.code, kReviewInvalid);
      verifyNever(() => client.from(any()));
    });
  });

  group('Batch 1 — analytics re-queue', () {
    test('failed flush retains events for the next flush', () async {
      final sent = <String>[];
      final service = AnalyticsService(sink: _FlakySink(sent));
      service.log(AnalyticsService.purchase);

      await service.flush(); // first attempt throws inside the sink
      expect(sent, isEmpty);

      await service.flush(); // retry succeeds
      expect(sent, [AnalyticsService.purchase]);
      service.dispose();
    });
  });

  group('Batch 1 — wishlist error codes', () {
    test('load failure carries a stable code, not just a message', () async {
      final cubit = WishlistCubit(_FailingWishlistRepo());
      await cubit.restore(force: true);

      expect(cubit.state.status, WishlistStatus.error);
      expect(cubit.state.errorCode, 'wishlist_load_failed');
      expect(cubit.state.errorMessage, isNotNull);
      await cubit.close();
    });
  });
}
