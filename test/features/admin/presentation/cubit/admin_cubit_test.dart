import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
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

void main() {
  late _MockAdminRepository repo;

  setUp(() {
    repo = _MockAdminRepository();
  });

  group('AdminCubit.loadOrders', () {
    blocTest<AdminCubit, AdminState>(
      'emits loading then ready with typed orders on Success',
      build: () {
        when(() => repo.getAllOrders(status: any(named: 'status')))
            .thenAnswer((_) async =>
                Success([_order('o1', AdminOrderStatus.paid)]));
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
            .having(
                (s) => s.orders[0].status, 'orders[0].status', AdminOrderStatus.paid),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits error with repository message on Failure',
      build: () {
        when(() => repo.getAllOrders(status: any(named: 'status')))
            .thenAnswer(
                (_) async => Failure(AppError('Failed to load orders')));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrders(),
      expect: () => [
        isA<AdminState>().having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', 'Failed to load orders'),
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
        isA<AdminState>().having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.ready)
            .having(
                (s) => s.statusFilter, 'statusFilter', AdminOrderStatus.shipped)
            .having(
                (s) => s.filteredOrders.map((o) => o.id).toList(),
                'filteredOrders',
                ['o2']),
      ],
    );
  });

  group('AdminCubit.loadOrderDetails', () {
    blocTest<AdminCubit, AdminState>(
      'emits ready with selectedOrder when found',
      build: () {
        when(() => repo.getOrderDetails('o1'))
            .thenAnswer((_) async => Success(_order('o1', AdminOrderStatus.paid)));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrderDetails('o1'),
      expect: () => [
        isA<AdminState>().having((s) => s.status, 'status', AdminStatus.loading),
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
        isA<AdminState>().having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', 'Order not found'),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits error with repository message on Failure',
      build: () {
        when(() => repo.getOrderDetails('o1'))
            .thenAnswer((_) async => Failure(AppError('Failed to load order')));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.loadOrderDetails('o1'),
      expect: () => [
        isA<AdminState>().having((s) => s.status, 'status', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', 'Failed to load order'),
      ],
    );
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
        when(() => repo.getAllOrders(status: any(named: 'status')))
            .thenAnswer((_) async =>
                Success([_order('o1', AdminOrderStatus.processing)]));
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
        verify(() => repo.getAllOrders(status: any(named: 'status')))
            .called(1);
      },
    );

    blocTest<AdminCubit, AdminState>(
      'emits error and does not reload on Failure',
      build: () {
        when(() => repo.updateOrderStatus(
              'o1',
              AdminOrderStatus.cancelled,
              trackingNumber: null,
            )).thenAnswer(
                (_) async => Failure(AppError('Failed to update order status')));
        return AdminCubit(repo);
      },
      act: (cubit) =>
          cubit.updateOrderStatus('o1', AdminOrderStatus.cancelled),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having(
                (s) => s.errorMessage,
                'errorMessage',
                'Failed to update order status'),
      ],
    );
  });

  group('AdminCubit low stock', () {
    blocTest<AdminCubit, AdminState>(
      'loadLowStockProducts emits typed variants on Success',
      build: () {
        when(() => repo.getLowStockProducts(threshold: 5)).thenAnswer(
            (_) async => Success(const [
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
        when(() => repo.updateStock('v1', 9))
            .thenAnswer((_) async => Failure(AppError('Failed to update stock')));
        return AdminCubit(repo);
      },
      act: (cubit) => cubit.updateStock('v1', 9),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminStatus.error)
            .having(
                (s) => s.errorMessage, 'errorMessage', 'Failed to update stock'),
      ],
    );
  });
}
