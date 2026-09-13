import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart'
    show OrderCodec;
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reorder_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/orders_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/products_data.dart';
import '../helpers/memory_storefront_persistence.dart';

/// OrdersPage depends on the app-scoped ReorderCubit (§6). Harnesses
/// that pump the page directly provide an inert instance here.
Widget _withReorderCubit(Widget child) => BlocProvider<ReorderCubit>(
      create: (_) => ReorderCubit(
        catalog: _NoCatalog(),
        addToCart: (_, {color = '', length = '', quantity = 1}) {},
      ),
      child: child,
    );

class _NoCatalog implements CatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('orders page shows a placed order in the Active tab',
      (WidgetTester tester) async {
    final store = MemoryStorefrontPersistence();
    store.orderRecords = [
      OrderCodec.encode(Order(
        id: 'ORD-2026-0001',
        items: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ],
        subtotal: products.first.price * 2,
        shipping: Money.zero,
        total: products.first.price * 2,
        status: OrderStatus.placed,
        placedAt: DateTime.utc(2026, 1, 1),
        paymentMethod: 'Credit Card',
      )),
    ];
    final orders = OrdersCubit(store);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: orders,
        child: _withReorderCubit(const OrdersPage()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('My Orders'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.textContaining('#ORD-'), findsOneWidget);
    expect(find.textContaining('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('Placed'), findsOneWidget);
    await orders.close();
  });
}
