import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_sales.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/presentation/admin_order_status_label.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/sales_low_stock_list.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/sales_status_counts_list.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/sales_top_products_list.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit 2026-09-19, sweep part 34 (Tier 3). Two defects this pins, both from the
/// old "admin copy is intentionally English in-code" convention:
///
///  1. the status chip printed the raw DB enum name (`status.name.toUpperCase()`
///     → "SHIPPED"), so Arabic admins read English shouted copy;
///  2. the sales panels hardcoded their headings and the `N left` / `N u` counts.
///
/// Asserted at the widget level as well as the key level, because a key-only test
/// would still pass if a widget forgot to call it.
Widget _harness(Widget child, {Locale? locale}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  group('adminOrderStatusLabel', () {
    test('every status has copy in both locales, and Arabic is not English',
        () {
      for (final status in AdminOrderStatus.values) {
        final english = adminOrderStatusLabel(en, status);
        final arabic = adminOrderStatusLabel(ar, status);
        expect(english, isNotEmpty, reason: '$status in EN');
        expect(arabic, isNotEmpty, reason: '$status in AR');
        expect(arabic, isNot(english),
            reason: '$status is still English in AR');
      }
    });

    test('the raw enum name is never what the admin reads', () {
      // The old behaviour, asserted as absent so a regression fails here.
      for (final status in AdminOrderStatus.values) {
        expect(adminOrderStatusLabel(en, status),
            isNot(status.name.toUpperCase()));
        expect(adminOrderStatusLabel(ar, status),
            isNot(status.name.toUpperCase()));
      }
      expect(adminOrderStatusLabel(en, AdminOrderStatus.shipped), 'Shipped');
      expect(adminOrderStatusLabel(ar, AdminOrderStatus.shipped), 'تم الشحن');
    });
  });

  group('sales panels in Arabic', () {
    testWidgets('status counts render localized status names, not enum names',
        (tester) async {
      await tester.pumpWidget(_harness(
        const SalesStatusCountsCard(counts: [
          AdminSalesStatusCount(status: AdminOrderStatus.paid, count: 9),
          AdminSalesStatusCount(status: AdminOrderStatus.unknown, count: 1),
        ]),
        locale: const Locale('ar'),
      ));

      expect(find.text('الطلبات حسب الحالة'), findsOneWidget);
      expect(find.text('مدفوع'), findsOneWidget);
      expect(find.text('غير معروف'), findsOneWidget);
      // Nothing shouted, nothing English.
      expect(find.text('PAID'), findsNothing);
      expect(find.text('Paid'), findsNothing);
      expect(find.text('UNKNOWN'), findsNothing);
    });

    testWidgets('low stock heading, empty state and the plural count',
        (tester) async {
      await tester.pumpWidget(_harness(
        const SalesLowStockCard(variants: [
          LowStockVariant(
            variantId: 'v1',
            productName: 'Crimson Lace',
            size: '2m',
            color: 'Crimson',
            stock: 0,
          ),
          LowStockVariant(
            variantId: 'v2',
            productName: 'Emerald Silk',
            size: '1m',
            color: 'Emerald',
            stock: 2,
          ),
        ]),
        locale: const Locale('ar'),
      ));

      // The threshold in the heading is the widget constant, interpolated.
      expect(
          find.text('مخزون منخفض (≤ ${SalesLowStockCard.lowStockThreshold})'),
          findsOneWidget);
      expect(find.text('لا شيء متبقٍ'), findsOneWidget); // count 0
      expect(find.text('يتبقّى 2'), findsOneWidget); // count 2
      expect(find.textContaining('low stock'), findsNothing);
    });

    testWidgets('low stock empty state is localized', (tester) async {
      await tester.pumpWidget(_harness(
        const SalesLowStockCard(variants: []),
        locale: const Locale('ar'),
      ));

      expect(find.text('لا شيء تحت الحد'), findsOneWidget);
      expect(find.text('Nothing below the threshold'), findsNothing);
    });

    testWidgets('best sellers heading and the unit count', (tester) async {
      await tester.pumpWidget(_harness(
        const SalesTopProductsCard(products: [
          AdminTopProduct(productName: 'Emerald Silk', unitsSold: 4),
        ]),
        locale: const Locale('ar'),
      ));

      expect(find.text('الأكثر مبيعًا — الوحدات المبيعة'), findsOneWidget);
      expect(find.text('4 وحدة'), findsOneWidget);
      expect(find.text('4 u'), findsNothing);
    });
  });
}
