import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reorder_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/orders_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FlakyOrders implements OrdersRepository {
  bool fail = true;
  int reads = 0;

  @override
  Future<Result<List<Order>>> readOrders() async {
    reads++;
    return fail
        ? const Failure(AppError('orders unavailable'))
        : const Success([]);
  }
}

final class _NoCatalog implements CatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Order _ghostOrder() => Order(
      id: 'ORD-GHOST',
      items: const [
        CartItem(
          product: Product(
            id: 'ghost',
            name: 'Ghost Fabric',
            category: 'Silk',
            price: Money.egp(100),
            imageColor: 0xFF176B57,
          ),
          color: 'Emerald',
          length: '1m',
        ),
      ],
      subtotal: const Money.egp(100),
      shipping: Money.zero,
      total: const Money.egp(100),
      status: OrderStatus.pending,
      placedAt: DateTime.utc(2026, 10, 21),
      paymentMethod: 'cod',
    );

Widget _harness(OrdersCubit orders, ReorderCubit reorder) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: orders),
          BlocProvider.value(value: reorder),
        ],
        child: const OrdersPage(),
      ),
    );

void main() {
  testWidgets('a load failure offers Retry and recovers to the tabs',
      (tester) async {
    final repo = _FlakyOrders();
    final orders = OrdersCubit(repo);
    addTearDown(orders.close);
    final reorder = ReorderCubit(
      catalog: _NoCatalog(),
      addToCart: (_, {color = '', length = '', quantity = 1}) {},
    );
    addTearDown(reorder.close);

    await tester.pumpWidget(_harness(orders, reorder));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('a completed reorder reports added/skipped counts and resets',
      (tester) async {
    final orders = OrdersCubit(_FlakyOrders()..fail = false);
    addTearDown(orders.close);
    final reorder = ReorderCubit(
      catalog: _NoCatalog(),
      addToCart: (_, {color = '', length = '', quantity = 1}) {},
    );
    addTearDown(reorder.close);

    await tester.pumpWidget(_harness(orders, reorder));
    await tester.pumpAndSettle();

    await reorder.reorder(_ghostOrder());
    await tester.pump();

    expect(
        find.textContaining('Nothing was added to your cart'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsOneWidget);
    expect(reorder.state.status, ReorderStatus.idle);
  });
}
