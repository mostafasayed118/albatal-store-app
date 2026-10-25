import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/data/back_in_stock_alert_store.dart';
import 'package:al_batal_elite/features/storefront/data/catalog_persistent_cache.dart';
import 'package:al_batal_elite/features/storefront/data/local_cart_repository.dart';
import 'package:al_batal_elite/features/storefront/data/local_wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/features/storefront/data/review_mapper.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_wishlist_sync_remote.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/coupon_discount.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/auth_session_port.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/idempotency_store.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_sync_remote.dart';
import 'package:al_batal_elite/features/storefront/domain/usecases/place_checkout_order_usecase.dart';
import 'package:al_batal_elite/features/storefront/presentation/catalog_fabric_label.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_state.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/flash_sale_ticker.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reviews_cubit.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _product = Product(
  id: 'p1',
  name: 'Royal Silk',
  category: 'Silk',
  price: Money(1000),
  imageColor: 0xFF176B57,
);

final class _ThrowingPrefs extends Fake implements SharedPreferences {
  final writes = <String, String>{};

  @override
  String? getString(String key) => throw Exception('disk unavailable');

  @override
  Future<bool> setString(String key, String value) async {
    writes[key] = value;
    throw Exception('disk unavailable');
  }
}

final class _StubPrefs extends Fake implements SharedPreferences {
  _StubPrefs(this.values);

  final Map<String, String?> values;

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

final class _ThrowingMap extends Fake implements Map<Object?, Object?> {
  @override
  dynamic operator [](Object? key) => throw StateError('boom');
}

final class _FailingWriteCart implements CartRepository {
  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      const Success([]);

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async =>
      const Failure(AppError('disk full', code: 'save_failed'));
}

final class _MockClient extends Mock implements SupabaseClient {}

final class _FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  _FakeRpc(this.payload, {this.error});

  final Object? payload;
  final Object? error;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    if (error != null) {
      return Future<dynamic>.error(error!).then(onValue, onError: onError);
    }
    return Future<dynamic>.value(payload).then(onValue, onError: onError);
  }
}

final class _MockAuth extends Mock implements GoTrueClient {}

final class _MockUser extends Mock implements User {}

final class _MockStorageClient extends Mock implements SupabaseStorageClient {}

final class _MockFileApi extends Mock implements StorageFileApi {}

final class _LocalWishlist implements WishlistRepository {
  _LocalWishlist(this.ids, {required this.failRead, this.failWrite = false});

  Set<String> ids;
  final bool failRead;
  final bool failWrite;

  @override
  Future<Result<Set<String>>> readWishlist() async => failRead
      ? const Failure(AppError('nope', code: 'load_failed'))
      : Success({...ids});

  @override
  Future<Result<void>> writeWishlist(Set<String> next) async {
    if (failWrite) return const Failure(AppError('nope', code: 'save_failed'));
    ids = {...next};
    return const Success(null);
  }
}

final class _RemoteWishlist implements WishlistSyncRemote {
  _RemoteWishlist(this.server);

  Set<String> server;

  @override
  Future<Set<String>> syncWishlist(Set<String> localIds) async =>
      server = {...server, ...localIds};
}

final class _Session implements AuthSessionPort {
  _Session(this.email);

  final String? email;

  @override
  String? currentUserEmail() => email;
}

final class _RetryOutcomeRepo implements CheckoutRepository {
  _RetryOutcomeRepo({required this.first, required this.second});

  final Result<PendingOrder> first;
  final Result<PendingOrder> second;
  int calls = 0;

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Address? address,
    String? couponCode,
    String? idempotencyKey,
  }) async {
    calls++;
    return calls == 1 ? first : second;
  }
}

final class _MemoryKeyStore implements IdempotencyStore {
  String? key;
  int? ts;

  @override
  String? loadKey() => key;

  @override
  int? loadTimestampMs() => ts;

  @override
  Future<void> saveKey(String key, int timestampMs) async {
    this.key = key;
    ts = timestampMs;
  }

  @override
  Future<void> clear() async {
    key = null;
    ts = null;
  }
}

PendingOrder _pending(OrderStatus status) => PendingOrder(
      orderId: 'ord-1',
      subtotal: const Money(1000),
      shipping: Money.zero,
      total: const Money(1000),
      expiresAt: DateTime.utc(2026, 1, 1),
      status: status,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
  });

  group('PrefsBackInStockAlertStore', () {
    test('toggles watchers and reads the empty list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PrefsBackInStockAlertStore(prefs);

      expect(store.watchedProductIds, isEmpty);
      expect(store.isWatched('p1'), isFalse);

      store.setWatched('p1', true);
      expect(store.isWatched('p1'), isTrue);
      expect(store.watchedProductIds, {'p1'});

      store.setWatched('p1', false);
      expect(store.isWatched('p1'), isFalse);
      expect(store.watchedProductIds, isEmpty);
    });
  });

  group('FlashSaleTicker', () {
    test('exposes null before start and clamps a negative remaining', () {
      fakeAsync((async) {
        var now = DateTime.utc(2026, 1, 1, 12);
        final ticker = FlashSaleTicker(now: () => now);

        expect(ticker.remaining, isNull);

        final ticks = <Duration>[];
        var done = 0;
        ticker.start(
          now.subtract(const Duration(seconds: 1)),
          onTick: ticks.add,
          onDone: () => done++,
        );

        expect(ticks.single, Duration.zero);
        expect(done, 1);
        expect(ticker.remaining, Duration.zero);
        async.flushMicrotasks();
      });
    });

    test('ticks once per second and fires onDone when the sale expires', () {
      fakeAsync((async) {
        var now = DateTime.utc(2026, 1, 1, 12);
        final ticker = FlashSaleTicker(now: () => now);
        final ticks = <Duration>[];
        var done = 0;

        ticker.start(
          now.add(const Duration(seconds: 2)),
          onTick: ticks.add,
          onDone: () => done++,
        );
        expect(ticks, [const Duration(seconds: 2)]);

        now = now.add(const Duration(seconds: 1));
        async.elapse(const Duration(seconds: 1));
        expect(ticks.last, const Duration(seconds: 1));
        expect(done, 0);

        now = now.add(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 1));
        expect(ticks.last, Duration.zero);
        expect(done, 1);
      });
    });
  });

  group('SupabaseWishlistSyncRemote', () {
    test('calls sync_wishlist with the local ids and decodes the result',
        () async {
      final client = _MockClient();
      when(() => client.rpc('sync_wishlist', params: any(named: 'params')))
          .thenAnswer((_) => _FakeRpc(['p1', 'p2']));

      final remote = SupabaseWishlistSyncRemote(client: client);
      final merged = await remote.syncWishlist({'p1'});

      expect(merged, {'p1', 'p2'});
      verify(() => client.rpc('sync_wishlist', params: {
            'p_product_ids': ['p1']
          })).called(1);
    });
  });

  group('CartCubit persistence failure', () {
    test('keeps the optimistic items and reports the error status', () async {
      final cubit = CartCubit(_FailingWriteCart());
      addTearDown(cubit.close);

      cubit.add(_product);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.items.single.product.id, 'p1');
      expect(cubit.state.status, CartStatus.error);
    });
  });

  group('Catalog persistent cache', () {
    test('a throwing prefs write records the attempt but stays unreadable',
        () async {
      final prefs = _ThrowingPrefs();

      await persistCatalogCache(prefs, const [_product]);

      expect(prefs.writes.keys, [catalogPersistentCacheKey]);
      final persisted = jsonDecode(prefs.writes.values.single) as List;
      expect(persisted, hasLength(1));
      expect((persisted.single as Map)['id'], 'p1');
      expect(await restoreCatalogCache(prefs), isNull);
    });

    test('large payloads decode through the isolate path', () async {
      final raw = jsonEncode([
        {
          'id': 'p1',
          'name': 'Royal Silk',
          'category': 'Silk',
          'price': 1000,
          'description': 'x' * 70000,
        },
      ]);
      expect(raw.length, greaterThan(64 * 1024));
      final prefs = _StubPrefs({catalogPersistentCacheKey: raw});

      final restored = await restoreCatalogCache(prefs);

      expect(restored, hasLength(1));
      expect(restored!.single.id, 'p1');
      expect(restored.single.description!.length, 70000);
    });
  });

  group('local repositories', () {
    test('a throwing prefs read maps to the load failure code', () async {
      final persistence = LocalStorefrontPersistence(_ThrowingPrefs());

      final cart = await LocalCartRepository(persistence).readCart((_) => null);
      final wishlist =
          await LocalWishlistRepository(persistence).readWishlist();

      expect((cart as Failure).error.code, 'load_failed');
      expect((wishlist as Failure).error.code, 'load_failed');
    });

    test('a throwing prefs write maps to the save failure code', () async {
      final persistence = LocalStorefrontPersistence(_ThrowingPrefs());

      final cart = await LocalCartRepository(persistence).writeCart(const []);
      final wishlist =
          await LocalWishlistRepository(persistence).writeWishlist({'p1'});

      expect((cart as Failure).error.code, 'save_failed');
      expect((wishlist as Failure).error.code, 'save_failed');
    });
  });

  group('OrderCodec', () {
    test('an entry without an id is skipped', () {
      final order = OrderCodec.decode({
        'items': const [],
        'status': 'placed',
        'placedAt': '2026-01-01T00:00:00Z',
      });

      expect(order, isNull);
    });

    test('a corrupt line is skipped without failing the order', () {
      final order = OrderCodec.decode({
        'items': [_ThrowingMap()],
        'status': 'placed',
        'id': 'o1',
        'placedAt': '2026-01-01T00:00:00Z',
      });

      expect(order, isNotNull);
      expect(order!.items, isEmpty);
    });

    test('a fully unreadable snapshot is skipped', () {
      expect(OrderCodec.decode(_ThrowingMap()), isNull);
    });
  });

  group('CatalogState derived views', () {
    test('a curated colorName wins over the variant colors', () {
      final state = CatalogState(allProducts: const [
        Product(
          id: 'p1',
          name: 'Silk',
          category: 'Silk',
          price: Money(100),
          imageColor: 0xFF000000,
          colorName: 'Crimson',
          colors: ['Red', 'Scarlet'],
        ),
      ]);

      expect(state.availableColors, ['Crimson']);
    });

    test('the name sort orders the visible list alphabetically', () {
      final state = CatalogState(
        allProducts: const [
          Product(
            id: 'p1',
            name: 'Zebra Silk',
            category: 'Silk',
            price: Money(100),
            imageColor: 0xFF000000,
          ),
          Product(
            id: 'p2',
            name: 'Amber Silk',
            category: 'Silk',
            price: Money(200),
            imageColor: 0xFF000000,
          ),
        ],
        filters: const CatalogFilters(sort: CatalogSort.name),
      );

      expect(state.visible.map((p) => p.name), ['Amber Silk', 'Zebra Silk']);
    });
  });

  group('Product mappers', () {
    test('a row without an old price maps to null', () {
      final product = ProductCodec.fromRow(
        {
          'id': 'p1',
          'name': 'Royal Silk',
          'base_price': 1000,
          'categories': {'name': 'Silk'},
          'product_variants': [],
          'product_images': [],
        },
        [],
        storageService: StorageService(client: null),
      );

      expect(product, isNotNull);
      expect(product!.oldPrice, isNull);
    });

    test('a fractional flash-sale discount truncates to an int', () {
      final sale = FlashSaleCodec.fromRow({
        'product_id': 'p1',
        'discount_pct': 12.9,
      });

      expect(sale, isNotNull);
      expect(sale!.discountPct, 12);
    });

    test('adminReviewToReview delegates to the row mapper', () {
      final review = adminReviewToReview({
        'id': 'r1',
        'product_id': 'p1',
        'rating': 4,
        'created_at': '2026-09-01T10:00:00Z',
        'author_name': 'Nour',
        'text': 'Nice',
      });

      expect(review, isNotNull);
      expect(review!.id, 'r1');
    });
  });

  group('entity equality', () {
    test('CouponDiscount compares all fields', () {
      const a = CouponDiscount(
          code: 'SILK10', discountMinor: 500, description: 'ten');
      const b = CouponDiscount(
          code: 'SILK10', discountMinor: 500, description: 'ten');
      const c = CouponDiscount(code: 'SILK10', discountMinor: 500);

      expect(a, b);
      expect(a, isNot(c));
    });

    test('ProductReview compares all fields', () {
      final created = DateTime.utc(2026, 9, 1);
      final a = ProductReview(
        id: 'r1',
        productId: 'p1',
        authorName: 'Nour',
        rating: 5,
        text: 'Great',
        createdAt: created,
        photoUrl: 'https://x/y.jpg',
      );
      final b = ProductReview(
        id: 'r1',
        productId: 'p1',
        authorName: 'Nour',
        rating: 5,
        text: 'Great',
        createdAt: created,
        photoUrl: 'https://x/y.jpg',
      );

      expect(a, b);
      final c = ProductReview(
        id: 'r2',
        productId: 'p1',
        authorName: 'Nour',
        rating: 5,
        text: 'Great',
        createdAt: created,
      );

      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('PlaceCheckoutOrderUseCase', () {
    test('a failed retry after a dead-order retry reports the failure',
        () async {
      final repo = _RetryOutcomeRepo(
        first: Success(_pending(OrderStatus.paid)),
        second: const Failure(AppError('retry failed')),
      );
      final store = _MemoryKeyStore();
      final usecase = PlaceCheckoutOrderUseCase(
        checkoutRepository: repo,
        idempotencyStore: store,
      );

      final outcome = await usecase(
        items: const [],
        paymentMethod: PaymentMethod.cashOnDelivery,
        inSessionKey: 'key-1',
      );

      expect(outcome.isSuccess, isFalse);
      expect(outcome.error?.message, 'retry failed');
      expect(repo.calls, 2);
      expect(outcome.idempotencyKey, isNot('key-1'));
    });
  });

  group('catalog fabric labels', () {
    test('unspecified bands fall back to Any', () {
      final l = lookupAppLocalizations(const Locale('en'));
      expect(fabricWeightLabel(l, FabricWeight.unspecified), 'Any');
      expect(fabricWidthLabel(l, FabricWidth.unspecified), 'Any');
    });
  });

  group('ReviewsCubit submit guard', () {
    test('submitting without a repository reports unavailable', () async {
      final cubit = ReviewsCubit();
      addTearDown(cubit.close);
      await cubit.load('p1');

      await cubit.submit(rating: 5, text: 'Lovely');

      expect(cubit.state.submitMessage, kReviewUnavailableCode);
    });
  });

  group('SupabaseReviewsRepository photo cleanup', () {
    test('a cleanup failure while unwinding is swallowed', () async {
      final client = _MockClient();
      final auth = _MockAuth();
      final user = _MockUser();
      final storage = _MockStorageClient();
      final fileApi = _MockFileApi();

      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('u1');
      when(() => client.storage).thenReturn(storage);
      when(() => storage.from('review-images')).thenReturn(fileApi);
      when(() => fileApi.uploadBinary(
            any(),
            any(),
            fileOptions: any(named: 'fileOptions'),
          )).thenAnswer((_) async => 'u1/p1/photo.jpg');
      when(() =>
              client.rpc('submit_product_review', params: any(named: 'params')))
          .thenAnswer((_) => _FakeRpc(null, error: Exception('offline')));
      when(() => fileApi.remove(any())).thenThrow(Exception('storage down'));

      final repo = SupabaseReviewsRepository(client: client);
      final result = await repo.submit(
        productId: 'p1',
        rating: 5,
        text: 'Lovely',
        photoBytes: [1, 2, 3],
      );

      expect(result, isA<Failure<ProductReview>>());
      verify(() => fileApi.remove(any())).called(1);
    });
  });

  group('SupabaseWishlistRepository merged persist', () {
    test('a failed local persist after sync surfaces the save failure',
        () async {
      final repo = SupabaseWishlistRepository(
        local: _LocalWishlist({'p1'}, failRead: false, failWrite: true),
        remote: _RemoteWishlist({'p2'}),
        session: _Session('a@b.c'),
      );

      final result = await repo.readWishlist();

      expect(result, isA<Failure<Set<String>>>());
      expect((result as Failure).error.code, 'save_failed');
    });
  });
}
