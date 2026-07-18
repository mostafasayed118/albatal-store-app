import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/orders_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('orders page shows a placed order in the Active tab',
      (WidgetTester tester) async {
    final store = MemoryStorefrontPersistence();
    final orders = OrdersCubit(store);
    orders.place(
      CartState([
        CartItem(
            product: products.first,
            color: 'Emerald',
            length: '2m',
            quantity: 2),
      ]),
      paymentMethod: 'Credit Card',
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: orders,
        child: const OrdersPage(),
      ),
    ));
    await tester.pump();

    expect(find.text('My Orders'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.textContaining('#ORD-'), findsOneWidget);
    expect(find.textContaining('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('Placed'), findsOneWidget);
  });
}
