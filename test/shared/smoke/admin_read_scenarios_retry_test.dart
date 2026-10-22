import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:al_batal_elite/shared/smoke/admin_read_scenarios.dart';
import 'package:al_batal_elite/shared/smoke/smoke_scenario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class _RetryRepository implements AdminRepository {
  int orderLoads = 0;
  int lowStockLoads = 0;

  @override
  Future<Result<List<AdminOrder>>> getAllOrders(
      {AdminOrderStatus? status, int limit = 50}) async {
    orderLoads++;
    if (orderLoads == 1) return const Failure(AppError('not rehydrated'));
    return const Success([]);
  }

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts(
      {int threshold = 5}) async {
    lowStockLoads++;
    // The scenario only retries while an error is still on the state, and
    // `AdminState.copyWith` drops `errorMessage` on every emit — so the
    // first pass must fail on BOTH reads, exactly like a session that has
    // not rehydrated yet.
    if (lowStockLoads == 1) return const Failure(AppError('not rehydrated'));
    return const Success([
      LowStockVariant(
        variantId: 'v1',
        productName: 'Silk',
        size: 'M',
        color: 'Emerald',
        stock: 2,
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('the dashboard scenario retries once after a session-settle error',
      () async {
    final repository = _RetryRepository();
    final cubit = AdminCubit(repository);
    addTearDown(cubit.close);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
    ]);
    addTearDown(router.dispose);

    final logs = <String>[];
    final ctx = SmokeContext(
      router: router,
      log: (message) async => logs.add(message),
      pump: ([duration = const Duration(milliseconds: 1)]) async {},
      adminCubit: cubit,
    );

    final checks = await adminReadScenarios()['admin_dashboard_data']!(ctx);

    expect(repository.orderLoads, 2);
    expect(logs.single, contains('retrying after session settle'));
    expect(checks.every((c) => c.ok), isTrue);
    expect(cubit.state.status, AdminStatus.ready);
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.lowStockProducts, hasLength(1));
  });
}
