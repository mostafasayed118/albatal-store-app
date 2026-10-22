import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/routing/app_routes.dart';
import 'package:al_batal_elite/shared/routing/route_pages.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class _PaymentService extends Fake implements PaymentService {}

void main() {
  testWidgets('a non-map extra reaches the payment page as empty args',
      (tester) async {
    getIt.registerSingleton<PaymentService>(_PaymentService());
    addTearDown(() async {
      await getIt.reset();
    });

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(
        path: Routes.paymentMethod,
        builder: (_, state) => RoutePages.paymentMethod(state),
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pump();

    router.go(Routes.paymentMethod, extra: 'not-a-map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(
        router.routeInformationProvider.value.uri.path, Routes.paymentMethod);
  });
}
