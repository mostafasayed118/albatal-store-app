import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reorder_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_card.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_status_timeline.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/local_catalog_repository.dart';

Order _order({required OrderStatus status, String productId = 'silk-01'}) =>
    Order(
      id: 'ORD-9',
      items: [
        CartItem(
          product: Product(
            id: productId,
            name: 'Royal Emerald Silk',
            category: 'Silk',
            price: const Money.egp(1290),
            imageColor: 0xFF176B57,
          ),
          color: 'Emerald',
          length: '1m',
        ),
      ],
      subtotal: const Money.egp(1290),
      shipping: Money.zero,
      total: const Money.egp(1290),
      status: status,
      placedAt: DateTime(2026, 9, 4),
      paymentMethod: 'cod',
    );

Widget _harness(
  Order order,
  ReorderCubit reorder, {
  bool isCompleted = false,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: reorder,
        child: Scaffold(
          body: Builder(
            builder: (context) => OrderCard(
              order: order,
              isCompleted: isCompleted,
              scheme: Theme.of(context).colorScheme,
            ),
          ),
        ),
      ),
    );

ReorderCubit _reorder({
  void Function(Product product, String color, String length, int quantity)?
      onAdd,
}) =>
    ReorderCubit(
      catalog: LocalCatalogRepository(),
      addToCart: (product, {color = '', length = '', quantity = 1}) =>
          onAdd?.call(product, color, length, quantity),
    );

void main() {
  testWidgets('tapping the card expands the order tracking timeline',
      (tester) async {
    final reorder = _reorder();
    addTearDown(reorder.close);

    await tester.pumpWidget(
      _harness(
        _order(status: OrderStatus.pending),
        reorder,
      ),
    );
    await tester.pump();

    expect(find.byType(OrderStatusTimeline), findsNothing);

    await tester.tap(find.text('#ORD-9'));
    await tester.pump();

    expect(find.text('Order tracking'), findsOneWidget);
    expect(find.byType(OrderStatusTimeline), findsOneWidget);

    await tester.tap(find.text('#ORD-9'));
    await tester.pump();

    expect(find.byType(OrderStatusTimeline), findsNothing);
  });

  testWidgets('the Reorder action rebuilds the cart through ReorderCubit',
      (tester) async {
    final added = <({String id, String color, String length, int quantity})>[];
    final reorder = _reorder(
      onAdd: (product, color, length, quantity) => added.add((
        id: product.id,
        color: color,
        length: length,
        quantity: quantity,
      )),
    );
    addTearDown(reorder.close);

    await tester.pumpWidget(
      _harness(_order(status: OrderStatus.pending), reorder),
    );
    await tester.pump();

    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();

    expect(added, hasLength(1));
    expect(added.single.id, 'silk-01');
    expect(added.single.color, 'Emerald');
    expect(added.single.length, '1m');
    expect(reorder.state.status, ReorderStatus.done);
    expect(reorder.state.addedCount, 1);
  });

  testWidgets('refunded and expired orders both read Cancelled',
      (tester) async {
    for (final status in [OrderStatus.refunded, OrderStatus.expired]) {
      final reorder = _reorder();
      addTearDown(reorder.close);

      await tester.pumpWidget(
        _harness(_order(status: status), reorder, isCompleted: true),
      );
      await tester.pump();

      expect(find.text('Cancelled'), findsOneWidget, reason: status.name);
    }
  });
}
