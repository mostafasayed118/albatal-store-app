import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/orders_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('orders page shows a reconciled paid order in the Active tab',
      (WidgetTester tester) async {
    final store = MemoryStorefrontPersistence();
    final orders = OrdersCubit(store);
    final now = DateTime.now();
    await orders.reconcile(Order(
      id: 'ORD-INT-1',
      items: [],
      subtotal: Money.zero,
      shipping: Money.zero,
      total: Money.zero,
      status: OrderStatus.paid,
      placedAt: now,
      paymentMethod: 'Credit Card',
    ));

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
    expect(find.textContaining('#ORD-INT-1'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });
}
