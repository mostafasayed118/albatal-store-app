import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/dashboard/admin_order_tile.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AdminOrder _order(AdminOrderStatus status, {String id = 'order-1'}) =>
    AdminOrder(
      id: id,
      status: status,
      total: const Money.egp(120),
      placedAt: DateTime(2026),
      customerName: 'Sara Ali',
      itemCount: 2,
    );

void main() {
  Widget harness(AdminOrder order) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AdminOrderTile(order: order)),
      );

  testWidgets('every status maps to its icon and row copy', (tester) async {
    const expected = <AdminOrderStatus, IconData>{
      AdminOrderStatus.placed: Icons.receipt_long,
      AdminOrderStatus.pending: Icons.autorenew,
      AdminOrderStatus.paid: Icons.autorenew,
      AdminOrderStatus.processing: Icons.autorenew,
      AdminOrderStatus.shipped: Icons.local_shipping,
      AdminOrderStatus.delivered: Icons.check_circle,
      AdminOrderStatus.cancelled: Icons.cancel,
      AdminOrderStatus.refunded: Icons.cancel,
      AdminOrderStatus.unknown: Icons.help_outline,
    };

    for (final entry in expected.entries) {
      await tester.pumpWidget(harness(_order(entry.key)));
      await tester.pump();

      expect(find.byIcon(entry.value), findsOneWidget,
          reason: 'missing icon for ${entry.key}');
      expect(find.text('Sara Ali · 2 items'), findsOneWidget);
    }
  });

  testWidgets('a missing customer name falls back to the unknown copy',
      (tester) async {
    await tester.pumpWidget(harness(AdminOrder(
      id: 'order-2',
      status: AdminOrderStatus.placed,
      total: Money.zero,
      placedAt: DateTime(2026),
      items: const [
        AdminOrderItem(
          productName: 'Silk',
          size: 'M',
          color: 'Navy',
          quantity: 1,
          unitPrice: Money.zero,
        ),
      ],
    )));
    await tester.pump();

    expect(find.text('Unknown · 1 items'), findsOneWidget);
  });

  testWidgets('tapping the row opens its order detail route', (tester) async {
    final router = GoRouter(
      initialLocation: '/admin/orders',
      routes: [
        GoRoute(
          path: '/admin/orders',
          builder: (_, __) => Scaffold(
            body: AdminOrderTile(
              order: _order(AdminOrderStatus.placed, id: 'order-9'),
            ),
          ),
        ),
        GoRoute(
          path: '/admin/orders/:id',
          builder: (_, state) => Scaffold(
            body: Text('detail ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AdminOrderTile));
    await tester.pumpAndSettle();

    expect(find.text('detail order-9'), findsOneWidget);
  });
}
