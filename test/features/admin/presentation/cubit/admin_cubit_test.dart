import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

AdminOrder _order(String id, AdminOrderStatus status) => AdminOrder(
      id: id,
      status: status,
      total: Money.zero,
      placedAt: DateTime(2026),
    );

AdminOrder _orderForCustomer(String id, String profileId) => AdminOrder(
      id: id,
      status: AdminOrderStatus.paid,
      total: Money.zero,
      placedAt: DateTime(2026),
      customerId: profileId,
      customerTier: 'standard',
    );

class _SeededAdminCubit extends AdminCubit {
  _SeededAdminCubit(super.repository);

  void seed(AdminState state) => emit(state);
}

void main() {
  late _MockAdminRepository repo;

  setUp(() {
    repo = _MockAdminRepository();
  });

  group('AdminCubit.loadOrders', () {
    blocTest<AdminCubit, AdminState>(
      'emits loading then ready with typed orders on Success',
      build: () {
        when(() => repo.getAllOrders(status: any(named: 'status'))).thenAnswer(
            (_) async => Success([_order('o1', AdminOrderStatus.paid)]));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrders(),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading)
            .having((s) => s.statusFilter, 'statusFilter', isNull),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.orders.length, 'orders.length', 1)
            .having((s) => s.orders[0].id, 'orders[0].id', 'o1')
            .having((s) => s.orders[0].status, 'orders[0].status',
                AdminOrderStatus.paid),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits error with repository message and code on Failure',
      build: () {
        when(() => repo.getAllOrders(status: any(named: 'status'))).thenAnswer(
            (_) async => const Failure(AppError('Failed to load orders',
                code: kAdminOrdersLoadFailed)));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrders(),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having(
                (s) => s.errorMessage, 'errorMessage', 'Failed to load orders')
            // The code is what the page localizes from; dropping it would
            // silently revert the admin console to English failure prose.
            .having((s) => s.errorCode, 'errorCode', kAdminOrdersLoadFailed),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'filteredOrders filters by typed status',
      build: () {
        when(() => repo.getAllOrders(status: any(named: 'status')))
            .thenAnswer((_) async => Success([
                  _order('o1', AdminOrderStatus.placed),
                  _order('o2', AdminOrderStatus.shipped),
                ]));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrders(status: AdminOrderStatus.shipped),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having(
                (s) => s.statusFilter, 'statusFilter', AdminOrderStatus.shipped)
            .having((s) => s.filteredOrders.map((o) => o.id).toList(),
                'filteredOrders', ['o2']),
      ],
    );

    test('a superseded filter response cannot overwrite the active queue',
        () async {
      final paid = Completer<Result<List<AdminOrder>>>();
      final shipped = Completer<Result<List<AdminOrder>>>();
      when(() => repo.getAllOrders(status: AdminOrderStatus.paid))
          .thenAnswer((_) => paid.future);
      when(() => repo.getAllOrders(status: AdminOrderStatus.shipped))
          .thenAnswer((_) => shipped.future);
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      // The admin taps Paid and then Shipped before Paid resolves.
      final first = cubit.loadOrders(status: AdminOrderStatus.paid);
      final second = cubit.loadOrders(status: AdminOrderStatus.shipped);

      shipped.complete(Success([_order('s1', AdminOrderStatus.shipped)]));
      await second;
      expect(cubit.state.statusFilter, AdminOrderStatus.shipped);
      expect(cubit.state.orders.single.id, 's1');

      paid.complete(Success([_order('p1', AdminOrderStatus.paid)]));
      await first;

      expect(cubit.state.orders.single.id, 's1',
          reason: 'the paid response belongs to a filter the admin left');
      expect(cubit.state.statusFilter, AdminOrderStatus.shipped);
      expect(cubit.state.status, AdminStatus.ready);
    });

    test('a superseded filter failure cannot error the active queue', () async {
      final paid = Completer<Result<List<AdminOrder>>>();
      final shipped = Completer<Result<List<AdminOrder>>>();
      when(() => repo.getAllOrders(status: AdminOrderStatus.paid))
          .thenAnswer((_) => paid.future);
      when(() => repo.getAllOrders(status: AdminOrderStatus.shipped))
          .thenAnswer((_) => shipped.future);
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      final first = cubit.loadOrders(status: AdminOrderStatus.paid);
      final second = cubit.loadOrders(status: AdminOrderStatus.shipped);

      shipped.complete(Success([_order('s1', AdminOrderStatus.shipped)]));
      await second;

      paid.complete(const Failure(AppError('stale filter failed')));
      await first;

      expect(cubit.state.status, AdminStatus.ready,
          reason: 'the failure belongs to a superseded request');
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.orders.single.id, 's1');
    });
  });

  group('AdminCubit.checkAdmin', () {
    blocTest<AdminCubit, AdminState>(
      'emits the access-denied code so the page can localize it',
      build: () {
        when(() => repo.isCurrentUserAdmin()).thenAnswer((_) async => false);
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.checkAdmin(),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having((s) => s.errorCode, 'errorCode', kAdminAccessDenied),
      ],
    );
  });

  group('AdminCubit.loadOrderDetails', () {
    blocTest<AdminCubit, AdminState>(
      'emits ready with selectedOrder when found',
      build: () {
        when(() => repo.getOrderDetails('o1')).thenAnswer(
            (_) async => Success(_order('o1', AdminOrderStatus.paid)));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrderDetails('o1'),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.selectedOrder?.id, 'selectedOrder.id', 'o1'),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits error when the order is not found (Success(null))',
      build: () {
        when(() => repo.getOrderDetails('missing'))
            .thenAnswer((_) async => const Success(null));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrderDetails('missing'),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', 'Order not found'),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits error with repository message on Failure',
      build: () {
        when(() => repo.getOrderDetails('o1')).thenAnswer(
            (_) async => const Failure(AppError('Failed to load order')));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrderDetails('o1'),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having(
                (s) => s.errorMessage, 'errorMessage', 'Failed to load order'),
      ],
    );

    test('a superseded detail response cannot replace the newer order',
        () async {
      final orderB = Completer<Result<AdminOrder?>>();
      final orderA = Completer<Result<AdminOrder?>>();
      when(() => repo.getOrderDetails('b')).thenAnswer((_) => orderB.future);
      when(() => repo.getOrderDetails('a')).thenAnswer((_) => orderA.future);
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      // Opening order B and then order A before B resolves.
      final first = cubit.loadOrderDetails('b');
      final second = cubit.loadOrderDetails('a');

      orderA.complete(Success(_order('a', AdminOrderStatus.paid)));
      await second;
      expect(cubit.state.selectedOrder?.id, 'a');

      orderB.complete(Success(_order('b', AdminOrderStatus.paid)));
      await first;

      expect(cubit.state.selectedOrder?.id, 'a',
          reason: 'order B was replaced by order A before B resolved');
      expect(cubit.state.status, AdminStatus.ready);
    });

    test('a superseded detail not-found cannot error the newer order',
        () async {
      final orderB = Completer<Result<AdminOrder?>>();
      final orderA = Completer<Result<AdminOrder?>>();
      when(() => repo.getOrderDetails('b')).thenAnswer((_) => orderB.future);
      when(() => repo.getOrderDetails('a')).thenAnswer((_) => orderA.future);
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      final first = cubit.loadOrderDetails('b');
      final second = cubit.loadOrderDetails('a');

      orderA.complete(Success(_order('a', AdminOrderStatus.paid)));
      await second;

      orderB.complete(const Success(null));
      await first;

      expect(cubit.state.selectedOrder?.id, 'a');
      expect(cubit.state.status, AdminStatus.ready,
          reason: 'B not existing must not fail the order A screen');
      expect(cubit.state.errorMessage, isNull);
    });
  });

  group('AdminCubit.updateOrderStatus', () {
    blocTest<AdminCubit, AdminState>(
      'reloads orders on Success',
      build: () {
        when(() => repo.updateOrderStatus(
              'o1',
              AdminOrderStatus.processing,
              trackingNumber: null,
            )).thenAnswer((_) async => const Success(null));
        when(() => repo.getAllOrders(status: any(named: 'status'))).thenAnswer(
            (_) async => Success([_order('o1', AdminOrderStatus.processing)]));
        return AdminCubit(repo);
      },
      act: (cubit) =>
          cubit.updateOrderStatus('o1', AdminOrderStatus.processing),
      verify: (_) {
        verify(() => repo.updateOrderStatus(
              'o1',
              AdminOrderStatus.processing,
              trackingNumber: null,
            )).called(1);
        verify(() => repo.getAllOrders(status: any(named: 'status'))).called(1);
      },
    );

    blocTest<AdminCubit, AdminState>(
      'refreshes selectedOrder from the reloaded queue on Success',
      build: () {
        when(() => repo.updateOrderStatus(
              'o1',
              AdminOrderStatus.processing,
              trackingNumber: null,
            )).thenAnswer((_) async => const Success(null));
        when(() => repo.getAllOrders(status: any(named: 'status'))).thenAnswer(
            (_) async => Success([_order('o1', AdminOrderStatus.processing)]));
        return AdminCubit(repo);
      },
      seed: () =>
          AdminState(selectedOrder: _order('o1', AdminOrderStatus.paid)),
      act: (cubit) =>
          cubit.updateOrderStatus('o1', AdminOrderStatus.processing),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading)
            // Reload emits carry the stale detail until the final one fixes it.
            .having((s) => s.selectedOrder?.status, 'selectedOrder.status',
                AdminOrderStatus.paid),
        // The reload's own ready emit: queue updated, detail still stale.
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.orders[0].status, 'orders[0].status',
                AdminOrderStatus.processing)
            .having((s) => s.selectedOrder?.status, 'selectedOrder.status',
                AdminOrderStatus.paid),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.selectedOrder?.id, 'selectedOrder.id', 'o1')
            .having((s) => s.selectedOrder?.status, 'selectedOrder.status',
                AdminOrderStatus.processing),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'keeps the detail valid when the transitioned order left the queue',
      build: () {
        when(() => repo.updateOrderStatus(
              'o1',
              AdminOrderStatus.cancelled,
              trackingNumber: null,
            )).thenAnswer((_) async => const Success(null));
        // A filtered queue (or changed status outside the filter) no longer
        // contains the order — the detail must not read as "order not found".
        when(() => repo.getAllOrders(status: any(named: 'status')))
            .thenAnswer((_) async => const Success([]));
        return AdminCubit(repo);
      },
      seed: () =>
          AdminState(selectedOrder: _order('o1', AdminOrderStatus.paid)),
      act: (cubit) => cubit.updateOrderStatus('o1', AdminOrderStatus.cancelled),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.orders, 'orders', isEmpty)
            // The reload's own ready emit still carries the stale detail.
            .having((s) => s.selectedOrder?.id, 'selectedOrder.id', 'o1'),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.selectedOrder?.id, 'selectedOrder.id', 'o1')
            .having((s) => s.selectedOrder?.status, 'selectedOrder.status',
                AdminOrderStatus.cancelled),
      ],
    );

    test(
        'a confirmed transition out of the active filter keeps the detail open',
        () async {
      when(() => repo.updateOrderStatus(
            'o1',
            AdminOrderStatus.cancelled,
            trackingNumber: null,
          )).thenAnswer((_) async => const Success(null));
      when(() => repo.getAllOrders(status: AdminOrderStatus.paid))
          .thenAnswer((_) async => const Success([]));
      final cubit = _SeededAdminCubit(repo)
        ..seed(AdminState(
          status: AdminStatus.ready,
          orders: [_order('o1', AdminOrderStatus.paid)],
          selectedOrder: _order('o1', AdminOrderStatus.paid),
          statusFilter: AdminOrderStatus.paid,
        ));
      addTearDown(cubit.close);

      await cubit.updateOrderStatus('o1', AdminOrderStatus.cancelled);

      expect(cubit.state.statusFilter, AdminOrderStatus.paid);
      expect(cubit.state.orders, isEmpty,
          reason: 'the order left the active queue');
      expect(cubit.state.selectedOrder?.id, 'o1',
          reason: 'a successful update must not render "order not found"');
      expect(cubit.state.selectedOrder?.status, AdminOrderStatus.cancelled);
    });

    test('a confirmed shipment records the tracking number on the open detail',
        () async {
      when(() => repo.updateOrderStatus(
            'o1',
            AdminOrderStatus.shipped,
            trackingNumber: 'EG-9',
          )).thenAnswer((_) async => const Success(null));
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => const Success([]));
      final cubit = _SeededAdminCubit(repo)
        ..seed(AdminState(
          status: AdminStatus.ready,
          selectedOrder: _order('o1', AdminOrderStatus.processing),
        ));
      addTearDown(cubit.close);

      await cubit.updateOrderStatus(
        'o1',
        AdminOrderStatus.shipped,
        trackingNumber: 'EG-9',
      );

      expect(cubit.state.selectedOrder?.status, AdminOrderStatus.shipped);
      expect(cubit.state.selectedOrder?.trackingNumber, 'EG-9');
    });

    blocTest<AdminCubit, AdminState>(
      'leaves selectedOrder untouched when a different order changed',
      build: () {
        when(() => repo.updateOrderStatus(
              'o2',
              AdminOrderStatus.processing,
              trackingNumber: null,
            )).thenAnswer((_) async => const Success(null));
        when(() => repo.getAllOrders(status: any(named: 'status')))
            .thenAnswer((_) async => const Success([]));
        return AdminCubit(repo);
      },
      seed: () =>
          AdminState(selectedOrder: _order('o1', AdminOrderStatus.paid)),
      act: (cubit) =>
          cubit.updateOrderStatus('o2', AdminOrderStatus.processing),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.selectedOrder?.id, 'selectedOrder.id', 'o1'),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits error and does not reload on Failure',
      build: () {
        when(() => repo.updateOrderStatus(
                  'o1',
                  AdminOrderStatus.cancelled,
                  trackingNumber: null,
                ))
            .thenAnswer((_) async =>
                const Failure(AppError('Failed to update order status')));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.updateOrderStatus('o1', AdminOrderStatus.cancelled),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having((s) => s.errorMessage, 'errorMessage',
                'Failed to update order status'),
      ],
    );
  });

  group('AdminCubit low stock', () {
    blocTest<AdminCubit, AdminState>(
      'loadLowStockProducts emits typed variants on Success',
      build: () {
        when(() => repo.getLowStockProducts(threshold: 5))
            .thenAnswer((_) async => const Success([
                  LowStockVariant(
                    variantId: 'v1',
                    productName: 'Silk',
                    size: '1m',
                    color: 'Emerald',
                    stock: 2,
                  ),
                ]));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadLowStockProducts(),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.lowStockProducts.length, 'lowStock.length', 1)
            .having((s) => s.lowStockProducts[0].variantId, 'variantId', 'v1'),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'updateStock reloads low stock on Success',
      build: () {
        when(() => repo.updateStock('v1', 9))
            .thenAnswer((_) async => const Success(null));
        when(() => repo.getLowStockProducts(threshold: 5))
            .thenAnswer((_) async => const Success([]));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.updateStock('v1', 9),
      verify: (_) {
        verify(() => repo.updateStock('v1', 9)).called(1);
        verify(() => repo.getLowStockProducts(threshold: 5)).called(1);
      },
    );

    blocTest<AdminCubit, AdminState>(
      'updateStock emits error on Failure',
      build: () {
        when(() => repo.updateStock('v1', 9)).thenAnswer(
            (_) async => const Failure(AppError('Failed to update stock')));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.updateStock('v1', 9),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having((s) => s.errorMessage, 'errorMessage',
                'Failed to update stock'),
      ],
    );
  });

  group('AdminCubit.setMembershipTier', () {
    blocTest<AdminCubit, AdminState>(
      'updates the open order customer tier on Success (no full reload)',
      seed: () => AdminState(
        status: AdminStatus.ready,
        selectedOrder: _orderForCustomer('o1', 'profile-9'),
      ),
      build: () {
        when(() => repo.setMembershipTier('profile-9', 'premium'))
            .thenAnswer((_) async => const Success(null));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.setMembershipTier('profile-9', 'premium'),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having((s) => s.selectedOrder?.customerTier, 'tier', 'premium'),
      ],
      verify: (_) {
        verify(() => repo.setMembershipTier('profile-9', 'premium')).called(1);
      },
    );

    blocTest<AdminCubit, AdminState>(
      'no-op selection (same tier) emits nothing',
      seed: () => AdminState(
        status: AdminStatus.ready,
        selectedOrder: _orderForCustomer('o1', 'profile-9'),
      ),
      build: () {
        when(() => repo.setMembershipTier('profile-9', 'standard'))
            .thenAnswer((_) async => const Success(null));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.setMembershipTier('profile-9', 'standard'),
      expect: () => [],
    );

    blocTest<AdminCubit, AdminState>(
      'success for another customer never mutates the open order',
      seed: () => AdminState(
        status: AdminStatus.ready,
        selectedOrder: _orderForCustomer('o1', 'profile-9'),
      ),
      build: () {
        when(() => repo.setMembershipTier('profile-OTHER', 'premium'))
            .thenAnswer((_) async => const Success(null));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.setMembershipTier('profile-OTHER', 'premium'),
      expect: () => [],
    );

    blocTest<AdminCubit, AdminState>(
      'emits error with repository message on Failure',
      seed: () => AdminState(
        status: AdminStatus.ready,
        selectedOrder: _orderForCustomer('o1', 'profile-9'),
      ),
      build: () {
        when(() => repo.setMembershipTier('profile-9', 'premium')).thenAnswer(
            (_) async => const Failure(AppError('tier change rejected')));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.setMembershipTier('profile-9', 'premium'),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having(
                (s) => s.errorMessage, 'errorMessage', 'tier change rejected'),
      ],
    );
  });
}
