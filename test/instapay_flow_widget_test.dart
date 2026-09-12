import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/instapay_instructions_page.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/payment_method_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/products_data.dart';
import 'helpers/instapay_stub.dart';
import 'helpers/memory_storefront_persistence.dart';

void main() {
  group('InstaPay client flow — widgets', () {
    late InstapayStub stub;
    late PaymentCubit cubit;
    late CartCubit cart;

    setUp(() {
      stub = InstapayStub(
        initiation: const InstapayReady(instructions: readyInstructions),
      );
      cubit = buildReadyCubit(stub);
      cart = CartCubit(MemoryStorefrontPersistence())
        ..add(products.first, color: 'Emerald', length: '2m', quantity: 1);
    });

    tearDown(() async {
      await stub.watchController.close();
    });

    GoRouter router() => GoRouter(
          initialLocation: '/payment-method',
          routes: [
            GoRoute(
              path: '/payment-method',
              builder: (_, __) => BlocProvider.value(
                value: cart,
                child: PaymentMethodPage(
                  paymentCubit: cubit,
                  args: const {
                    'orderId': 'ord-server-123',
                    'total': Money(129000),
                    'customerEmail': 'a@b.c',
                  },
                ),
              ),
            ),
            GoRoute(
              path: '/instapay-instructions',
              builder: (_, s) => InstapayInstructionsPage(
                cubit:
                    (s.extra as Map<String, dynamic>)['cubit'] as PaymentCubit,
              ),
            ),
          ],
        );

    Widget harness() => MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router(),
        );

    testWidgets(
        'method page offers InstaPay and routes to instructions '
        'with the SAME cubit', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('InstaPay'), findsOneWidget);
      expect(find.text('Pay with Card'), findsOneWidget);
      expect(find.text('Cash on Delivery'), findsOneWidget);

      await tester.tap(find.text('InstaPay'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Pay Now'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Pay Now'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      // Server-derived details are rendered — never client values.
      expect(find.text('instapay@merchant'), findsOneWidget);
      expect(find.text('1290 EGY'), findsOneWidget);
      // The instructions page received the same cubit instance, so the
      // single status watch keeps running across the push.
      expect(cubit.state.status, PaymentStatus.awaitingProof);
      expect(find.byType(InstapayInstructionsPage), findsOneWidget);

      // Stop the 15-min watch timer inside the test body — the
      // framework's pending-timer invariant fires before tearDown.
      // cancel() cancels the timer synchronously (first statement of
      // _stopWatching); awaiting close() here hangs on stream
      // teardown under the test fake-async zone.
      cubit.cancel();
    });

    testWidgets('submit stays disabled until a screenshot is attached',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('InstaPay'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Pay Now'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Pay Now'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit proof for review'),
      );
      expect(button.onPressed, isNull);
      expect(stub.proofCalls, isEmpty);

      cubit.cancel();
    });
  });
}
