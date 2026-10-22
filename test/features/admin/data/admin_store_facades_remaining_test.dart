import 'dart:async';

import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/admin_customers_store.dart';
import 'package:al_batal_elite/features/admin/data/admin_orders_store.dart';
import 'package:al_batal_elite/features/admin/data/admin_reviews_store.dart';
import 'package:al_batal_elite/features/admin/data/admin_sales_store.dart';
import 'package:al_batal_elite/features/admin/data/admin_wholesale_prices_store.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/supabase_admin_fakes.dart';

/// Remaining worker coverage for the admin data layer.
///
/// Each worker is constructed directly (not through the facade) so the
/// success/malformed branches its facade tests cannot reach are exercised
/// against a stubbed PostgREST chain.

class _UpdateBuilder extends Fake implements SupabaseQueryBuilder {
  _UpdateBuilder(this.filters);

  final _AwaitableFilter filters;

  @override
  PostgrestFilterBuilder<PostgrestMap> update(
    Map<dynamic, dynamic> values,
  ) {
    expect(values, isNotEmpty);
    return filters;
  }
}

class _AwaitableFilter extends Fake
    implements PostgrestFilterBuilder<PostgrestMap> {
  _AwaitableFilter(this.payload);

  final Map<String, dynamic> payload;

  @override
  PostgrestFilterBuilder<PostgrestMap> eq(String column, Object? value) => this;

  @override
  Future<R> then<R>(FutureOr<R> Function(PostgrestMap value) onValue,
          {Function? onError}) =>
      Future.value(payload).then(onValue, onError: onError);
}

void main() {
  group('SupabaseAdminSales', () {
    late MockSupabaseClient client;
    late SupabaseAdminSales sales;

    setUp(() {
      client = MockSupabaseClient();
      sales = SupabaseAdminSales(client: client);
    });

    test('getLowStockProducts maps RPC rows', () async {
      when(() => client
              .rpc('get_low_stock_products', params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder([
                {
                  'id': 'v1',
                  'product_name': 'Emerald Silk',
                  'variant_size': 'M',
                  'variant_color': 'Emerald',
                  'current_stock': 1,
                },
              ]));

      final result = await sales.getLowStockProducts(threshold: 2);

      final rows = (result as Success).value;
      expect(rows, hasLength(1));
      expect(rows.single.variantId, 'v1');
      expect(rows.single.stock, 1);
      verify(() =>
              client.rpc('get_low_stock_products', params: {'p_threshold': 2}))
          .called(1);
    });

    test('getSalesOverview maps the RPC aggregate payload', () async {
      when(() =>
              client.rpc('admin_sales_overview', params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder({
                'revenue_by_day': [
                  {'day': '2026-09-12T00:00:00Z', 'revenue_minor': 4200},
                ],
                'top_products': [
                  {'product_name': 'Silk', 'units_sold': 3},
                ],
                'status_counts': [
                  {'status': 'paid', 'count': 1},
                ],
              }));

      final result = await sales.getSalesOverview(days: 7);

      final overview = (result as Success).value;
      expect(overview.revenueByDay.single.revenueMinor, 4200);
      expect(overview.topProducts.single.productName, 'Silk');
      expect(overview.statusCounts.single.status, AdminOrderStatus.paid);
      verify(() => client.rpc('admin_sales_overview', params: {'p_days': 7}))
          .called(1);
    });
  });

  group('SupabaseAdminOrders', () {
    late MockSupabaseClient client;
    late SupabaseAdminOrders orders;

    setUp(() {
      client = MockSupabaseClient();
      orders = SupabaseAdminOrders(client: client);
    });

    test('getAllOrders applies a status filter and maps the queue rows',
        () async {
      final builder = MockSupabaseQueryBuilder();
      final filters = FakeFilterBuilder<PostgrestList>([
        {
          'id': 'o1',
          'status': 'placed',
          'total': 25000,
          'placed_at': '2026-09-16T10:00:00.000000Z',
          'profiles': {'full_name': 'Layla'},
          'order_items': [
            {'id': 'i1'},
          ],
        },
      ]);
      when(() => client.from('orders')).thenAnswer((_) => builder);
      when(() => builder.select(any())).thenAnswer((_) => filters);

      final result = await orders.getAllOrders(status: AdminOrderStatus.placed);

      final queue = (result as Success).value;
      expect(queue.single.id, 'o1');
      expect(queue.single.status, AdminOrderStatus.placed);
      expect(queue.single.customerName, 'Layla');
      expect(queue.single.itemCount, 1);
    });

    test('updateOrderStatus refuses the unknown status before any RPC',
        () async {
      final result =
          await orders.updateOrderStatus('o1', AdminOrderStatus.unknown);

      expect((result as Failure).error.code, kAdminOrderStatusInvalid);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });

    test('updateOrderStatus sends the transition and tracking number',
        () async {
      when(() =>
              client.rpc('update_order_status', params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(null));

      final result = await orders.updateOrderStatus(
        'o1',
        AdminOrderStatus.shipped,
        trackingNumber: 'TRACK-9',
      );

      expect(result, isA<Success<void>>());
      verify(() => client.rpc('update_order_status', params: {
            'p_order_id': 'o1',
            'p_new_status': 'shipped',
            'p_tracking_number': 'TRACK-9',
          })).called(1);
    });
  });

  group('SupabaseAdminReviews', () {
    test('setReviewStatus writes through update().eq()', () async {
      final client = MockSupabaseClient();
      final filters = _AwaitableFilter(const <String, dynamic>{});
      when(() => client.from('product_reviews'))
          .thenAnswer((_) => _UpdateBuilder(filters));

      final result = await SupabaseAdminReviews(client: client)
          .setReviewStatus('r1', 'approved');

      expect(result, isA<Success<void>>());
    });
  });

  group('SupabaseAdminCustomers', () {
    test('setMembershipTier calls the admin RPC', () async {
      final client = MockSupabaseClient();
      when(() => client.rpc('admin_set_membership_tier',
              params: any(named: 'params')))
          .thenAnswer((_) => FakeRpcBuilder(null));

      final result = await SupabaseAdminCustomers(client: client)
          .setMembershipTier('profile-1', 'premium');

      expect(result, isA<Success<void>>());
      verify(() => client.rpc('admin_set_membership_tier', params: {
            'p_profile_id': 'profile-1',
            'p_tier': 'premium',
          })).called(1);
    });
  });

  group('SupabaseAdminWholesalePrices', () {
    test('deleteWholesalePrice rejects a blank id before any RPC', () async {
      final client = MockSupabaseClient();

      final result = await SupabaseAdminWholesalePrices(client: client)
          .deleteWholesalePrice('   ');

      expect((result as Failure).error.code, kAdminWholesalePriceDeleteFailed);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });
  });
}
