import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/admin_catalog_store.dart';
import 'package:al_batal_elite/features/admin/data/admin_coupons_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// Batch 1 regression guards: admin write-path input validation fails fast
/// with the same boundary codes instead of spending a server round-trip.
void main() {
  group('Batch 1 — coupon guards', () {
    test('blank code fails with the create code, no network call', () async {
      final client = _MockSupabaseClient();
      final repo = SupabaseAdminCoupons(client: client);

      final result = await repo.createCoupon(code: '   ', discountMinor: 500);

      expect(result, isA<Failure>());
      expect((result as Failure).error.code, kAdminCouponCreateFailed);
      verifyNever(() => client.from(any()));
    });

    test('non-positive discount fails with the create code, no network call',
        () async {
      final client = _MockSupabaseClient();
      final repo = SupabaseAdminCoupons(client: client);

      final result = await repo.createCoupon(code: 'SAVE10', discountMinor: 0);

      expect(result, isA<Failure>());
      expect((result as Failure).error.code, kAdminCouponCreateFailed);
      verifyNever(() => client.from(any()));
    });
  });

  group('Batch 1 — catalog upsert guards', () {
    Future<SupabaseAdminCatalog> catalog(_MockSupabaseClient client) async =>
        SupabaseAdminCatalog(client: client);

    test('blank product name fails with the save code, no RPC', () async {
      final client = _MockSupabaseClient();
      final repo = await catalog(client);

      final result = await repo.adminUpsertProduct(
        name: '  ',
        slug: 'cotton',
        categoryId: 'c1',
        basePrice: const Money(1000),
        isActive: true,
      );

      expect(result, isA<Failure>());
      expect((result as Failure).error.code, kAdminProductSaveFailed);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('non-positive price fails with the save code, no RPC', () async {
      final client = _MockSupabaseClient();
      final repo = await catalog(client);

      final result = await repo.adminUpsertProduct(
        name: 'Cotton',
        slug: 'cotton',
        categoryId: 'c1',
        basePrice: const Money(0),
        isActive: true,
      );

      expect(result, isA<Failure>());
      expect((result as Failure).error.code, kAdminProductSaveFailed);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('blank variant size fails with the variant code, no RPC', () async {
      final client = _MockSupabaseClient();
      final repo = await catalog(client);

      final result = await repo.adminUpsertVariant(
        productId: 'p1',
        size: '',
        color: 'Emerald',
        stock: 5,
      );

      expect(result, isA<Failure>());
      expect((result as Failure).error.code, kAdminVariantSaveFailed);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('negative variant stock fails with the variant code, no RPC',
        () async {
      final client = _MockSupabaseClient();
      final repo = await catalog(client);

      final result = await repo.adminUpsertVariant(
        productId: 'p1',
        size: 'M',
        color: 'Emerald',
        stock: -1,
      );

      expect(result, isA<Failure>());
      expect((result as Failure).error.code, kAdminVariantSaveFailed);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });
  });
}
