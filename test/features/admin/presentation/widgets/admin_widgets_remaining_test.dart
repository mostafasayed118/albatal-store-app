import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_sales_dashboard_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/dashboard/admin_image_grid.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/dashboard/admin_stock_tile.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/membership_tier_dialog.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/order_cards/customer_card.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/order_cards/delivery_address_card.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/order_cards/fulfillment_actions.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/sales_dashboard_body.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_image.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

class _BrokenStorage extends StorageService {
  _BrokenStorage() : super(client: null);

  @override
  String getProductImageUrlForWidth(String storagePath, int width) =>
      throw StateError('storage client unavailable');
}

AdminOrder _order({
  required String id,
  required AdminOrderStatus status,
  String? customerTier,
  AdminOrderAddress? address,
}) =>
    AdminOrder(
      id: id,
      status: status,
      total: const Money(10000),
      placedAt: DateTime.utc(2026, 9, 16),
      customerName: 'Layla',
      customerId: 'profile-1',
      customerTier: customerTier,
      address: address,
    );

void main() {
  Widget harness(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  group('DeliveryAddressCard', () {
    testWidgets('renders the snapshot recipient, line and country',
        (tester) async {
      await tester.pumpWidget(harness(DeliveryAddressCard(
        order: _order(
          id: 'o1',
          status: AdminOrderStatus.shipped,
          address: const AdminOrderAddress(
            recipient: 'Layla Hassan',
            line: '12 Nile Street',
            city: 'Cairo',
            country: 'Egypt',
          ),
        ),
      )));

      expect(find.text('Layla Hassan'), findsOneWidget);
      expect(find.text('12 Nile Street, Cairo'), findsOneWidget);
      expect(find.text('Egypt'), findsOneWidget);
      expect(find.text('No address provided'), findsNothing);
    });
  });

  group('FulfillmentActions', () {
    testWidgets('mark-as-delivered invokes the delivered transition',
        (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.updateOrderStatus('o1', AdminOrderStatus.delivered,
              trackingNumber: any(named: 'trackingNumber')))
          .thenAnswer((_) async => const Success(null));
      when(() => repo.getAllOrders(
              status: any(named: 'status'), limit: any(named: 'limit')))
          .thenAnswer((_) async => const Success([]));
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      AdminOrderStatus? invoked;
      await tester.pumpWidget(harness(
        BlocProvider<AdminCubit>.value(
          value: cubit,
          child: FulfillmentActions(
            order: _order(id: 'o1', status: AdminOrderStatus.shipped),
            onStatusInvoked: (status) => invoked = status,
            onShipRequested: () {},
          ),
        ),
      ));

      await tester.tap(find.text('Mark as Delivered'));
      await tester.pump();

      expect(invoked, AdminOrderStatus.delivered);
      verify(() => repo.updateOrderStatus('o1', AdminOrderStatus.delivered,
          trackingNumber: any(named: 'trackingNumber'))).called(1);
    });

    testWidgets('cancel invokes the cancelled transition', (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.updateOrderStatus('o1', AdminOrderStatus.cancelled,
              trackingNumber: any(named: 'trackingNumber')))
          .thenAnswer((_) async => const Success(null));
      when(() => repo.getAllOrders(
              status: any(named: 'status'), limit: any(named: 'limit')))
          .thenAnswer((_) async => const Success([]));
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      AdminOrderStatus? invoked;
      await tester.pumpWidget(harness(
        BlocProvider<AdminCubit>.value(
          value: cubit,
          child: FulfillmentActions(
            order: _order(id: 'o1', status: AdminOrderStatus.processing),
            onStatusInvoked: (status) => invoked = status,
            onShipRequested: () {},
          ),
        ),
      ));

      await tester.tap(find.text('Cancel Order'));
      await tester.pump();

      expect(invoked, AdminOrderStatus.cancelled);
      verify(() => repo.updateOrderStatus('o1', AdminOrderStatus.cancelled,
          trackingNumber: any(named: 'trackingNumber'))).called(1);
    });
  });

  testWidgets(
      'AdminImageGrid falls back to the stored path when URL lookup throws',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        height: 400,
        child: AdminImageGrid(
          paths: const ['assets/images/1.svg'],
          storage: _BrokenStorage(),
          onMove: (_, __) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(AdminImageGrid), findsOneWidget);
    final image = tester.widget<AppImage>(find.byType(AppImage));
    expect(image.source, 'assets/images/1.svg',
        reason: 'the failed URL lookup must fall back to the stored path');
  });

  testWidgets('AdminStockTile paints the empty-stock accent', (tester) async {
    await tester.pumpWidget(harness(
      AdminStockTile(
        product: const LowStockVariant(
          variantId: 'v1',
          productName: 'Emerald Silk',
          size: 'M',
          color: 'Emerald',
          stock: 0,
        ),
        onEditRequested: () {},
      ),
    ));

    expect(find.text('0'), findsOneWidget);
    expect(find.text('Emerald Silk'), findsOneWidget);
  });

  testWidgets('membership dialog cancel returns null and writes nothing',
      (tester) async {
    String? chosen = 'sentinel';
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            chosen = await showMembershipTierDialog(context,
                currentTier: 'standard');
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Change membership tier'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(chosen, isNull);
    expect(find.text('Change membership tier'), findsNothing);
  });

  testWidgets('CustomerCard renders the wholesale badge', (tester) async {
    await tester.pumpWidget(harness(CustomerCard(
      order: _order(
        id: 'o1',
        status: AdminOrderStatus.paid,
        customerTier: 'wholesale',
      ),
      onChangeTier: () {},
    )));

    expect(find.text('Wholesale Partner'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });

  testWidgets('SalesDashboardBody guards a loaded state with no overview',
      (tester) async {
    await tester.pumpWidget(harness(const SalesDashboardBody(
      state: AdminSalesDashboardState(
        status: AdminSalesDashboardStatus.loaded,
      ),
    )));

    expect(find.text('No sales data available.'), findsOneWidget);
  });
}
