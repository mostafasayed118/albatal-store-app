// ============================================================
// OrdersPage auto-load tests (live-found 2026-09-03).
//
// The orders screen never fetched: restore() was only wired to
// the empty-state action button, so users with server-side
// orders saw permanently empty tabs. The page must load on open.
// ============================================================

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/orders_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingOrdersRepo implements OrdersRepository {
  int readCalls = 0;
  List<Order> ordersToReturn = const [];

  @override
  Future<Result<List<Order>>> readOrders() async {
    readCalls++;
    return Success(ordersToReturn);
  }

  @override
  Future<Result<void>> writeOrders(List<Order> orders) async =>
      const Success(null);
}

Widget _harness(OrdersCubit cubit) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider.value(
      value: cubit,
      child: const OrdersPage(),
    ),
  );
}

void main() {
  group('OrdersPage auto-load', () {
    testWidgets('fetches orders on open', (tester) async {
      final repo = _RecordingOrdersRepo();
      final cubit = OrdersCubit(repo);

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(repo.readCalls, 1,
          reason: 'opening the orders screen must trigger a fetch');

      await cubit.close();
    });

    testWidgets('server pending order appears in the active tab',
        (tester) async {
      final repo = _RecordingOrdersRepo()
        ..ordersToReturn = [
          Order(
            id: 'SERVER-PENDING-1',
            items: const [],
            subtotal: Money.egp(820),
            shipping: Money.zero,
            total: Money.egp(820),
            status: OrderStatus.pending,
            placedAt: DateTime.utc(2026, 9, 3),
            paymentMethod: 'cod',
          ),
        ];
      final cubit = OrdersCubit(repo);

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(find.textContaining('SERVER-PENDING-1'), findsOneWidget,
          reason:
              'server pending order must be visible without manual refresh');

      await cubit.close();
    });
  });
}
