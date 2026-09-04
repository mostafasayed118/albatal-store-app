import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Closed orders must show their own outcome — paid orders read "Paid",
/// cancelled ones "Cancelled", never a hardcoded "Delivered"
/// (live-found 2026-09-04).
void main() {
  group('OrderCard closed labels', () {
    Future<void> pumpCard(
      WidgetTester tester,
      OrderStatus status,
      bool isCompleted,
    ) {
      final order = Order(
        id: 'ORD-9',
        items: [
          CartItem(
              product: const Product(
                id: 'p1',
                name: 'Royal Emerald Silk',
                category: 'Silk',
                price: Money.egp(1290),
                imageColor: 0xFF176B57,
              ),
              color: 'Emerald',
              length: '1m',
              quantity: 1),
        ],
        subtotal: const Money.egp(1290),
        shipping: Money.zero,
        total: const Money.egp(1290),
        status: status,
        placedAt: DateTime(2026, 9, 4),
        paymentMethod: 'cod',
      );
      return tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => OrderCard(
            order: order,
            isCompleted: isCompleted,
            scheme: Theme.of(context).colorScheme,
          ),
        ),
      ));
    }

    testWidgets('paid order reads Paid, not Placed or Delivered',
        (tester) async {
      await pumpCard(tester, OrderStatus.paid, true);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.textContaining('Placed'), findsNothing);
      expect(find.textContaining('Delivered'), findsNothing);
    });

    testWidgets('cancelled order reads Cancelled with its date',
        (tester) async {
      await pumpCard(tester, OrderStatus.cancelled, true);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.textContaining('Delivered'), findsNothing);
    });

    testWidgets('delivered order still reads Delivered', (tester) async {
      await pumpCard(tester, OrderStatus.delivered, true);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.textContaining('Delivered'), findsNWidgets(2));
    });
  });
}
