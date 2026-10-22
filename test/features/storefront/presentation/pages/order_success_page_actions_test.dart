import 'package:al_batal_elite/features/storefront/presentation/pages/order_success_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The success page's two CTAs are the only exits from the screen — both
/// must route (and the empty-reference variant must route too).
GoRouter _router({required String orderId}) => GoRouter(
      initialLocation: '/success',
      routes: [
        GoRoute(
          path: '/success',
          builder: (_, __) => OrderSuccessPage(orderId: orderId),
        ),
        GoRoute(
          path: '/profile/orders',
          builder: (_, __) => const Scaffold(body: Text('Orders stub')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home stub')),
        ),
      ],
    );

Widget _app(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

void main() {
  testWidgets('tracking the order routes to the order history', (tester) async {
    await tester.pumpWidget(_app(_router(orderId: 'ord-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track My Order'));
    await tester.pumpAndSettle();

    expect(find.text('Orders stub'), findsOneWidget);
  });

  testWidgets('continuing shopping routes back to the home page',
      (tester) async {
    await tester.pumpWidget(_app(_router(orderId: 'ord-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue Shopping'));
    await tester.pumpAndSettle();

    expect(find.text('Home stub'), findsOneWidget);
  });

  testWidgets('a missing order reference still routes to the order history',
      (tester) async {
    await tester.pumpWidget(_app(_router(orderId: '   ')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.text('Track My Order'));
    await tester.pumpAndSettle();

    expect(find.text('Orders stub'), findsOneWidget);
  });
}
