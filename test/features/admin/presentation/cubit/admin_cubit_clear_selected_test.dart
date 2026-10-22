import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

class _SeededAdminCubit extends AdminCubit {
  _SeededAdminCubit(super.repository);

  void seed(AdminState state) => emit(state);
}

AdminOrder _order(String id) => AdminOrder(
      id: id,
      status: AdminOrderStatus.paid,
      total: const Money(10000),
      placedAt: DateTime.utc(2026, 9, 16),
      customerName: 'Layla',
      customerId: 'profile-1',
    );

void main() {
  test('clearSelectedOrder drops the detail view without touching the queue',
      () {
    final order = _order('o1');
    final cubit = _SeededAdminCubit(_MockAdminRepository())
      ..seed(AdminState(
        status: AdminStatus.ready,
        orders: [order],
        selectedOrder: order,
      ))
      ..clearSelectedOrder();

    expect(cubit.state.selectedOrder, isNull);
    expect(cubit.state.orders, [order]);
    expect(cubit.state.status, AdminStatus.ready);

    cubit.close();
  });
}
