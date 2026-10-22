import 'dart:async';

import 'package:al_batal_elite/features/payments/presentation/widgets/invalid_checkout_body.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('renders the guard-rejection copy and returns to payment',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/invalid-checkout',
          builder: (_, __) => const InvalidCheckoutBody(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    unawaited(router.push('/invalid-checkout'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      find.text(
          'The payment checkout link is invalid. Please return and retry.'),
      findsOneWidget,
    );
    expect(find.text('Return to payment'), findsOneWidget);
    expect(find.text('Complete Payment'), findsOneWidget);

    await tester.tap(find.text('Return to payment'));
    await tester.pumpAndSettle();

    expect(find.byType(InvalidCheckoutBody), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
