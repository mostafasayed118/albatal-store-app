import 'package:al_batal_elite/features/admin/presentation/pages/admin_catalog_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Stand-in destination so the test verifies navigation without booting the
/// real inventory page (which needs its own cubit/DI wiring).
const _inventoryMarker = Key('inventory-destination');

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/admin/catalog',
    routes: [
      GoRoute(
        path: '/admin/catalog',
        builder: (_, __) => const AdminCatalogPage(),
      ),
      GoRoute(
        path: '/admin/inventory',
        builder: (_, __) => const Scaffold(
          body: SizedBox(key: _inventoryMarker),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  group('AdminCatalogPage', () {
    testWidgets('shows a single management tile and no dead tiles',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Only the wired "Variants & stock" tile remains.
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      // The previously dead tiles were removed.
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
      expect(find.byIcon(Icons.category_outlined), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('Variants tile navigates to the inventory route',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(_inventoryMarker), findsNothing);

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.byKey(_inventoryMarker), findsOneWidget);
    });
  });
}
