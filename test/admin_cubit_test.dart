import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdminRepository implements AdminRepository {
  _StubAdminRepository({
    this.isAdmin = true,
    this.orders = const [],
    this.lowStock = const [],
    this.shouldThrowOnLoad = false,
  });

  final bool isAdmin;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> lowStock;
  final bool shouldThrowOnLoad;

  @override
  Future<bool> isCurrentUserAdmin() async => isAdmin;

  @override
  Future<List<Map<String, dynamic>>> getAllOrders({
    String? status,
    int limit = 50,
  }) async {
    if (shouldThrowOnLoad) throw Exception('DB error');
    if (status != null) {
      return orders.where((o) => o['status'] == status).toList();
    }
    return orders;
  }

  @override
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async => null;

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? trackingNumber,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getLowStockProducts({
    int threshold = 5,
  }) async {
    if (shouldThrowOnLoad) throw Exception('DB error');
    return lowStock;
  }

  @override
  Future<void> updateStock(String variantId, int newStock) async {}
}

void main() {
  group('AdminCubit — loadDashboard', () {
    blocTest<AdminCubit, AdminState>(
      'emits loading then ready with orders and low stock',
      build: () => AdminCubit(_StubAdminRepository(
        isAdmin: true,
        orders: [
          {'id': '1', 'status': 'placed'},
          {'id': '2', 'status': 'shipped'},
        ],
        lowStock: [
          {'product_name': 'Silk', 'current_stock': 2},
        ],
      )),
      act: (cubit) => cubit.loadDashboard(),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, '1: loading', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, '2: ready', AdminStatus.ready),
      ],
      verify: (cubit) {
        expect(cubit.state.isAdmin, isTrue);
        expect(cubit.state.orders.length, 2);
        expect(cubit.state.lowStockProducts.length, 1);
      },
    );

    blocTest<AdminCubit, AdminState>(
      'emits unauthorized when user is not admin',
      build: () => AdminCubit(_StubAdminRepository(isAdmin: false)),
      act: (cubit) => cubit.loadDashboard(),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, '1: loading', AdminStatus.loading),
        isA<AdminState>().having(
            (s) => s.status, '2: unauthorized', AdminStatus.unauthorized),
      ],
      verify: (cubit) {
        expect(cubit.state.isAdmin, isFalse);
      },
    );

    blocTest<AdminCubit, AdminState>(
      'emits error on repository failure',
      build: () => AdminCubit(_StubAdminRepository(
        isAdmin: true,
        shouldThrowOnLoad: true,
      )),
      act: (cubit) => cubit.loadDashboard(),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, '1: loading', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, '2: error', AdminStatus.error),
      ],
      verify: (cubit) {
        expect(cubit.state.isAdmin, isTrue);
        expect(cubit.state.errorMessage, isNotNull);
      },
    );

    blocTest<AdminCubit, AdminState>(
      'emits ready with empty lists when no data exists',
      build: () => AdminCubit(_StubAdminRepository(
        isAdmin: true,
        orders: [],
        lowStock: [],
      )),
      act: (cubit) => cubit.loadDashboard(),
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, '1: loading', AdminStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, '2: ready', AdminStatus.ready),
      ],
      verify: (cubit) {
        expect(cubit.state.orders, isEmpty);
        expect(cubit.state.lowStockProducts, isEmpty);
      },
    );

    test('initial state is initial with isAdmin false', () {
      final cubit = AdminCubit(_StubAdminRepository());
      expect(cubit.state.status, AdminStatus.initial);
      expect(cubit.state.isAdmin, false);
      cubit.close();
    });

    test('clearError transitions error to ready', () async {
      final cubit = AdminCubit(_StubAdminRepository(
        isAdmin: true,
        shouldThrowOnLoad: true,
      ));
      await cubit.loadDashboard();
      expect(cubit.state.status, AdminStatus.error);

      cubit.clearError();
      expect(cubit.state.status, AdminStatus.ready);
      await cubit.close();
    });
  });
}
