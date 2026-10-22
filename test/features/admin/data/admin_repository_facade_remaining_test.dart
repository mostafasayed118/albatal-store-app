import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/supabase_admin_repository.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/supabase_admin_fakes.dart';

/// Remaining facade coverage for [SupabaseAdminRepository].
///
/// The worker internals are already pinned elsewhere (`batch1_admin_guards_test`,
/// `admin_customer_directory_test`, mapper tests). These tests exist to execute
/// the thin delegation surface itself — every public method must hand its work
/// to the worker and keep failures inside the `Result` boundary (no exception
/// may escape a facade call).
class _MockAuth extends Mock implements GoTrueClient {}

class _ProfilesFrom extends Fake implements SupabaseQueryBuilder {
  _ProfilesFrom(this.filter);

  final _SingleFilter filter;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    expect(columns, 'is_admin');
    return filter;
  }
}

class _SingleFilter extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _SingleFilter(this.value);

  /// The awaited `.single()` payload. `dynamic` on purpose: one test plants a
  /// malformed payload to prove the hand-written catch denies instead of
  /// throwing out of the repository.
  final dynamic value;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object? value) {
    expect(column, 'id');
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap> single() => _SingleTransform(value);
}

class _SingleTransform extends Fake
    implements PostgrestTransformBuilder<PostgrestMap> {
  _SingleTransform(this.value);

  final dynamic value;

  @override
  Future<R> then<R>(FutureOr<R> Function(PostgrestMap value) onValue,
          {Function? onError}) =>
      Future.value(value as PostgrestMap).then(onValue, onError: onError);

  @override
  Future<PostgrestMap> catchError(Function onError,
          {bool Function(Object error)? test}) =>
      Future.value(value as PostgrestMap).catchError(onError, test: test);

  @override
  Future<PostgrestMap> whenComplete(FutureOr<void> Function() action) =>
      Future.value(value as PostgrestMap).whenComplete(action);

  @override
  Stream<PostgrestMap> asStream() =>
      Future.value(value as PostgrestMap).asStream();
}

void main() {
  late MockSupabaseClient client;

  setUp(() {
    client = MockSupabaseClient();
  });

  SupabaseAdminRepository repo() => SupabaseAdminRepository(client: client);

  void stubAuth(User? user) {
    final auth = _MockAuth();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
  }

  group('isCurrentUserAdmin', () {
    test('a signed-out visitor is denied without a profiles read', () async {
      stubAuth(null);

      expect(await repo().isCurrentUserAdmin(), isFalse);
      verifyNever(() => client.from(any()));
    });

    test('reads the admin flag through profiles.single()', () async {
      stubAuth(User.fromJson({
        'id': 'admin-1',
        'created_at': '2026-01-01T00:00:00Z',
      })!);
      when(() => client.from('profiles'))
          .thenAnswer((_) => _ProfilesFrom(_SingleFilter({'is_admin': true})));

      expect(await repo().isCurrentUserAdmin(), isTrue);
    });

    test('a failing probe is denied, never granted', () async {
      stubAuth(User.fromJson({
        'id': 'admin-1',
        'created_at': '2026-01-01T00:00:00Z',
      })!);
      when(() => client.from('profiles')).thenThrow(StateError('offline'));

      expect(await repo().isCurrentUserAdmin(), isFalse);
    });
  });

  group('worker delegation keeps failures inside the Result boundary', () {
    test('order queue reads and writes', () async {
      final repository = repo();

      final orders =
          await repository.getAllOrders(status: AdminOrderStatus.paid);
      expect((orders as Failure).error.code, kAdminOrdersLoadFailed);

      final details = await repository.getOrderDetails('o1');
      expect((details as Failure).error.code, kAdminOrderLoadFailed);

      final update = await repository.updateOrderStatus(
        'o1',
        AdminOrderStatus.processing,
        trackingNumber: 'TRACK-1',
      );
      expect((update as Failure).error.code, kAdminOrderStatusUpdateFailed);
    });

    test('sales reads', () async {
      final repository = repo();

      final lowStock = await repository.getLowStockProducts(threshold: 3);
      expect((lowStock as Failure).error.code, kAdminLowStockLoadFailed);

      final overview = await repository.getSalesOverview(days: 7);
      expect((overview as Failure).error.code, kAdminSalesLoadFailed);
    });

    test('catalog reads and writes', () async {
      final repository = repo();

      final stock = await repository.updateStock('v1', 4);
      expect((stock as Failure).error.code, kAdminStockUpdateFailed);

      final products = await repository.getAllProducts();
      expect((products as Failure).error.code, kAdminProductsLoadFailed);

      final product = await repository.getProductById('p1');
      expect((product as Failure).error.code, kAdminProductLoadFailed);

      final categories = await repository.getAllCategories();
      expect((categories as Failure).error.code, kAdminCategoriesLoadFailed);

      final upsertProduct = await repository.adminUpsertProduct(
        id: 'p1',
        name: 'Emerald Silk',
        slug: 'emerald-silk',
        description: 'A bolt of silk',
        composition: 'Silk',
        care: 'Dry clean',
        origin: 'Egypt',
        widthCm: 140,
        gsm: 90,
        sellByLength: true,
        minCutMeters: 1.5,
        categoryId: 'c1',
        basePrice: const Money(129000),
        isActive: true,
      );
      expect((upsertProduct as Failure).error.code, kAdminProductSaveFailed);

      final upsertVariant = await repository.adminUpsertVariant(
        productId: 'p1',
        size: 'M',
        color: 'Emerald',
        stock: 3,
        priceOverride: const Money(99000),
      );
      expect((upsertVariant as Failure).error.code, kAdminVariantSaveFailed);

      final images = await repository
          .adminSetProductImages('p1', ['product-images/p1/a.jpg']);
      expect((images as Failure).error.code, kAdminImagesSaveFailed);

      final variants = await repository.getVariants('p1');
      expect((variants as Failure).error.code, kAdminVariantsLoadFailed);

      final paths = await repository.getProductImagePaths('p1');
      expect((paths as Failure).error.code, kAdminImagesLoadFailed);
    });

    test('customer tier write', () async {
      final result = await repo().setMembershipTier('profile-1', 'premium');
      expect((result as Failure).error.code, kAdminMembershipUpdateFailed);
    });

    test('coupon reads and writes', () async {
      final repository = repo();

      final list = await repository.fetchCoupons();
      expect((list as Failure).error.code, kAdminCouponsLoadFailed);

      final created = await repository.createCoupon(
        code: 'SAVE10',
        discountMinor: 1000,
        description: 'Ten off',
      );
      expect((created as Failure).error.code, kAdminCouponCreateFailed);

      final toggled = await repository.setCouponActive('c1', false);
      expect((toggled as Failure).error.code, kAdminCouponUpdateFailed);
    });

    test('customer paging and page-size defaults delegate', () async {
      final result = await repo().fetchCustomers(
        query: 'Layla',
        cursor: (createdAt: '2026-09-16T10:00:00.000000Z', id: 'c1'),
        limit: 2,
      );
      expect((result as Failure).error.code, kAdminCustomersLoadFailed);
    });

    test('review moderation', () async {
      final repository = repo();

      final pending = await repository.fetchPendingReviews();
      expect((pending as Failure).error.code, kAdminReviewsLoadFailed);

      final status = await repository.setReviewStatus('r1', 'approved');
      expect((status as Failure).error.code, kAdminReviewUpdateFailed);
    });

    test('wholesale price list', () async {
      final repository = repo();

      final list = await repository.fetchWholesalePrices();
      expect((list as Failure).error.code, kAdminWholesalePricesLoadFailed);

      final upsert = await repository.upsertWholesalePrice(
          productId: 'p1', priceMinor: 5000);
      expect((upsert as Failure).error.code, kAdminWholesalePriceUpsertFailed);

      final delete = await repository.deleteWholesalePrice('p1');
      expect((delete as Failure).error.code, kAdminWholesalePriceDeleteFailed);
    });
  });
}
