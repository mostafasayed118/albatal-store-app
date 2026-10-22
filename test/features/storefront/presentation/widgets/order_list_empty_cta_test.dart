import 'package:al_batal_elite/features/storefront/presentation/widgets/order_list.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The empty order list must not dead-end: its CTA routes back into the
/// catalog.
void main() {
  testWidgets('the empty order list routes back to the catalog',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/orders',
      routes: [
        GoRoute(
          path: '/orders',
          builder: (context, __) => Scaffold(
            body: Builder(
              builder: (context) => OrderList(
                orders: const [],
                emptyMessage: 'No active orders',
                isCompleted: false,
                scheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/catalog',
          builder: (_, __) => const Scaffold(body: Text('Catalog stub')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active orders'), findsOneWidget);

    await tester.tap(find.text('Continue Shopping'));
    await tester.pumpAndSettle();

    expect(find.text('Catalog stub'), findsOneWidget);
  });
}
