import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_sales.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_sales_dashboard_page.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/sales_low_stock_list.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/sales_revenue_chart.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/sales_status_counts_list.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/sales_top_products_list.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

AdminSalesOverview _overview() => AdminSalesOverview(
      revenueByDay: [
        for (var i = 1; i <= 14; i++)
          AdminRevenuePoint(
            day: DateTime.utc(2026, 9, i),
            revenueMinor: i * 10000,
          ),
      ],
      topProducts: const [
        AdminTopProduct(productName: 'Emerald Silk', unitsSold: 12),
        AdminTopProduct(productName: 'Royal Velvet', unitsSold: 5),
      ],
      statusCounts: const [
        AdminSalesStatusCount(status: AdminOrderStatus.paid, count: 9),
        AdminSalesStatusCount(status: AdminOrderStatus.cancelled, count: 2),
      ],
    );

void main() {
  testWidgets(
    'renders revenue chart, status counts, best sellers and low stock',
    (tester) async {
      final repo = _MockAdminRepository();
      when(() => repo.getSalesOverview())
          .thenAnswer((_) async => Success(_overview()));
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success([
                LowStockVariant(
                  variantId: 'v1',
                  productName: 'Crimson Lace',
                  size: '2m',
                  color: 'Crimson',
                  stock: 0,
                ),
              ]));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminSalesDashboardPage(repository: repo),
        ),
      );
      // Loading frame, then the loaded frame; an extra beat lets the
      // chart's implicit entrance animation settle deterministically.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Sales Dashboard'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(SalesRevenueChartCard), findsOneWidget);
      expect(find.byType(SalesStatusCountsCard), findsOneWidget);
      expect(find.byType(SalesTopProductsCard), findsOneWidget);
      expect(find.text('Emerald Silk'), findsOneWidget);
      expect(find.text('Royal Velvet'), findsOneWidget);
      // The low-stock card sits below the fold; the ListView only builds
      // visible children, so scroll before asserting on it.
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();
      expect(find.byType(SalesLowStockCard), findsOneWidget);
      expect(find.text('Crimson Lace'), findsOneWidget);
      expect(find.text('0 left'), findsOneWidget);
    },
  );

  testWidgets('shows the error message on overview failure', (tester) async {
    final repo = _MockAdminRepository();
    when(() => repo.getSalesOverview()).thenAnswer(
        (_) async => const Failure(AppError('Failed to load sales overview')));
    when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
        .thenAnswer((_) async => const Success([]));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminSalesDashboardPage(repository: repo),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Failed to load sales overview'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('error state offers a retry that reloads the overview',
      (tester) async {
    final repo = _MockAdminRepository();
    when(() => repo.getSalesOverview()).thenAnswer(
        (_) async => const Failure(AppError('Failed to load sales overview')));
    when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
        .thenAnswer((_) async => const Success([]));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminSalesDashboardPage(repository: repo),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FeedbackView), findsOneWidget);

    when(() => repo.getSalesOverview())
        .thenAnswer((_) async => Success(_overview()));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    verify(() => repo.getSalesOverview()).called(2);
    expect(find.byType(BarChart), findsOneWidget,
        reason: 'the retry reloads instead of only clearing the error');
  });
}
