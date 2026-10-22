import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_sales.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_sales_dashboard_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_customers_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_inventory_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_orders_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_products_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_sales_dashboard_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/routing/app_routes.dart';
import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

class _NoopShareService implements ShareService {
  @override
  Future<void> shareText(String message) async {}

  @override
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {}
}

class _SeededAdminCubit extends AdminCubit {
  _SeededAdminCubit(super.repository);

  void seed(AdminState state) => emit(state);
}

class _SeededSalesCubit extends AdminSalesDashboardCubit {
  _SeededSalesCubit(AdminRepository repository) : super(repository: repository);

  void seed(AdminSalesDashboardState state) => emit(state);
}

AdminOrder _order(String id, AdminOrderStatus status) => AdminOrder(
      id: id,
      status: status,
      total: const Money(10000),
      placedAt: DateTime.utc(2026, 9, 16),
      customerName: 'Layla',
    );

AdminSalesOverview _overview(int revenue) => AdminSalesOverview(
      revenueByDay: [
        AdminRevenuePoint(
            day: DateTime.utc(2026, 9, 16), revenueMinor: revenue),
      ],
      topProducts: const [
        AdminTopProduct(productName: 'Emerald Silk', unitsSold: 2),
      ],
      statusCounts: const [
        AdminSalesStatusCount(status: AdminOrderStatus.paid, count: 1),
      ],
    );

Widget _app(Widget home, {double textScale = 1.0}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: home,
        ),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AdminOrderStatus.unknown);
  });

  group('AdminCustomersPage', () {
    testWidgets('a failed directory renders the retry that reloads it',
        (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.fetchCustomers(
          query: any(named: 'query'),
          cursor: any(named: 'cursor'),
          limit:
              any(named: 'limit'))).thenAnswer((_) async => const Failure(
          AppError('directory offline', code: 'admin_customers_load_failed')));

      await tester.pumpWidget(_app(AdminCustomersPage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);

      when(() =>
              repo.fetchCustomers(
                  query: any(named: 'query'),
                  cursor: any(named: 'cursor'),
                  limit: any(named: 'limit')))
          .thenAnswer((_) async => const Success((
                customers: <AdminCustomer>[],
                total: 0,
                nextCursor: null,
              )));

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      verify(() => repo.fetchCustomers(
          query: any(named: 'query'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'))).called(2);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a nameless customer falls back to its contact value',
        (tester) async {
      final repo = _MockAdminRepository();
      when(() =>
              repo.fetchCustomers(
                  query: any(named: 'query'),
                  cursor: any(named: 'cursor'),
                  limit: any(named: 'limit')))
          .thenAnswer((_) async => const Success((
                customers: [
                  AdminCustomer(
                    id: 'c1',
                    name: '',
                    phone: '0100',
                    tier: 'standard',
                    isBlocked: false,
                  ),
                ],
                total: 1,
                nextCursor: null,
              )));

      await tester.pumpWidget(_app(AdminCustomersPage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('?'), findsOneWidget);
      expect(find.text('0100'), findsOneWidget);
      expect(find.text('0100 • Standard Member'), findsOneWidget);
    });
  });

  group('AdminSalesDashboardPage', () {
    testWidgets('the Reload action re-reads both panels', (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.getSalesOverview())
          .thenAnswer((_) async => Success(_overview(1000)));
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success(<LowStockVariant>[]));

      await tester.pumpWidget(_app(AdminSalesDashboardPage(repository: repo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Reload'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => repo.getSalesOverview()).called(2);
    });

    testWidgets('buildWhen reruns for overview, low-stock and error deltas',
        (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.getSalesOverview())
          .thenAnswer((_) async => Success(_overview(1000)));
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success(<LowStockVariant>[]));
      final cubit = _SeededSalesCubit(repo);

      await tester.pumpWidget(_app(AdminSalesDashboardPage(cubit: cubit)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      cubit.seed(AdminSalesDashboardState(
        status: AdminSalesDashboardStatus.loaded,
        overview: _overview(2000),
      ));
      await tester.pump();

      cubit.seed(AdminSalesDashboardState(
        status: AdminSalesDashboardStatus.loaded,
        overview: _overview(2000),
        lowStock: const [
          LowStockVariant(
            variantId: 'v1',
            productName: 'Silk',
            size: 'M',
            color: 'Emerald',
            stock: 1,
          ),
        ],
      ));
      await tester.pump();

      cubit.seed(AdminSalesDashboardState(
        status: AdminSalesDashboardStatus.loaded,
        overview: _overview(2000),
        lowStock: const [
          LowStockVariant(
            variantId: 'v1',
            productName: 'Silk',
            size: 'M',
            color: 'Emerald',
            stock: 1,
          ),
        ],
        errorMessage: 'stale notice',
      ));
      await tester.pump();

      expect(find.text('Sales Dashboard'), findsOneWidget);
    });
  });

  group('AdminDashboardPage', () {
    testWidgets('each quick-action tile pushes its destination',
        (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.getAllOrders(
              status: any(named: 'status'), limit: any(named: 'limit')))
          .thenAnswer((_) async => const Success([]));
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success([]));
      when(() => repo.isCurrentUserAdmin()).thenAnswer((_) async => true);

      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: Routes.admin,
        routes: [
          GoRoute(
            path: Routes.admin,
            builder: (_, __) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: Routes.adminOrders,
            builder: (_, __) => Scaffold(
              appBar: AppBar(title: const Text('orders-destination')),
            ),
          ),
          GoRoute(
            path: Routes.adminInventory,
            builder: (_, __) => Scaffold(
              appBar: AppBar(title: const Text('inventory-destination')),
            ),
          ),
          GoRoute(
            path: Routes.adminCatalog,
            builder: (_, __) => Scaffold(
              appBar: AppBar(title: const Text('catalog-destination')),
            ),
          ),
          GoRoute(
            path: Routes.adminWholesalePrices,
            builder: (_, __) => Scaffold(
              appBar: AppBar(title: const Text('wholesale-destination')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      await tester.pumpWidget(BlocProvider<AdminCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pump();
      await tester.pump();

      for (final (label, destination) in [
        ('Order Queue', 'orders-destination'),
        ('Inventory', 'inventory-destination'),
        ('Catalog', 'catalog-destination'),
        ('Wholesale prices', 'wholesale-destination'),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(destination), findsOneWidget,
            reason: 'the $label tile must reach its destination');
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  });

  group('AdminInventoryPage', () {
    testWidgets('a failed load retries, then the edit dialog cancels',
        (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Failure(AppError('stock offline')));
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      await tester.pumpWidget(_app(
        BlocProvider<AdminCubit>.value(
          value: cubit,
          child: const AdminInventoryPage(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);

      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success([
                LowStockVariant(
                  variantId: 'v1',
                  productName: 'Emerald Silk',
                  size: 'M',
                  color: 'Emerald',
                  stock: 2,
                ),
              ]));

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      verify(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .called(2);
      expect(find.text('Emerald Silk'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Update Stock'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Update Stock'), findsNothing);
    });
  });

  group('AdminOrdersPage', () {
    testWidgets('buildWhen survives filter-only and list-only deltas',
        (tester) async {
      final repo = _MockAdminRepository();
      final first = [_order('o1', AdminOrderStatus.placed)];
      when(() => repo.getAllOrders(
          status: any(named: 'status'),
          limit: any(named: 'limit'))).thenAnswer((_) async => Success(first));
      final cubit = _SeededAdminCubit(repo);
      addTearDown(cubit.close);

      await tester.pumpWidget(_app(
        BlocProvider<AdminCubit>.value(
          value: cubit,
          child: AdminOrdersPage(shareService: _NoopShareService()),
        ),
      ));
      await tester.pump();
      await tester.pump();

      cubit.seed(AdminState(
        status: AdminStatus.ready,
        orders: first,
        statusFilter: AdminOrderStatus.placed,
      ));
      await tester.pump();

      cubit.seed(AdminState(
        status: AdminStatus.ready,
        orders: [_order('o2', AdminOrderStatus.placed)],
        statusFilter: AdminOrderStatus.placed,
      ));
      await tester.pump();

      expect(find.text('Order Queue'), findsOneWidget);
    });

    testWidgets('a failed queue renders a retry that reloads it',
        (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.getAllOrders(
              status: any(named: 'status'), limit: any(named: 'limit')))
          .thenAnswer((_) async => const Failure(AppError('queue offline')));
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);

      await tester.pumpWidget(_app(
        BlocProvider<AdminCubit>.value(
          value: cubit,
          child: AdminOrdersPage(shareService: _NoopShareService()),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);

      when(() => repo.getAllOrders(
              status: any(named: 'status'), limit: any(named: 'limit')))
          .thenAnswer((_) async => const Success([]));

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      verify(() => repo.getAllOrders(
          status: any(named: 'status'), limit: any(named: 'limit'))).called(2);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('AdminProductsPage', () {
    testWidgets('returning changed=true from the edit route reloads the list',
        (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.getAllProducts()).thenAnswer((_) async => const Success([
            AdminProduct(
              id: 'p1',
              name: 'Emerald Silk',
              slug: 'emerald-silk',
              categoryId: 'c1',
              categoryName: 'Silk',
              basePrice: Money(120000),
              isActive: true,
            ),
          ]));

      final router = GoRouter(
        initialLocation: Routes.adminProducts,
        routes: [
          GoRoute(
            path: Routes.adminProducts,
            builder: (_, __) => AdminProductsPage(repository: repo),
          ),
          GoRoute(
            path: '/admin/products/:id',
            builder: (context, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('finish-edit'),
                ),
              ),
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

      await tester.tap(find.byTooltip('Edit Product'));
      await tester.pumpAndSettle();
      expect(find.text('finish-edit'), findsOneWidget);

      await tester.tap(find.text('finish-edit'));
      await tester.pumpAndSettle();

      verify(() => repo.getAllProducts()).called(2);
      expect(find.text('Emerald Silk'), findsOneWidget);
    });
  });
}
