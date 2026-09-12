import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/instapay_instructions_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/instapay_stub.dart';

/// Router-backed harness: the page's status listener calls
/// `context.canPop()`, which requires a GoRouter in scope.
Widget _harness(Widget page) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [GoRoute(path: '/test', builder: (_, __) => page)],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  group('InstapayInstructionsPage orderId rehydration', () {
    late InstapayStub stub;

    setUp(() {
      stub = InstapayStub(
        initiation: const InstapayReady(instructions: readyInstructions),
      );
    });

    tearDown(() async {
      await stub.watchController.close();
      if (getIt.isRegistered<PaymentService>()) {
        getIt.unregister<PaymentService>();
      }
    });

    testWidgets('extra-cubit path keeps working alongside orderId',
        (tester) async {
      final cubit = buildReadyCubit(stub);
      addTearDown(cubit.cancel);
      // Drive to awaitingProof so the server-derived instructions render.
      await cubit.processPayment(customerEmail: 'a@b.c');

      await tester.pumpWidget(_harness(InstapayInstructionsPage(
        cubit: cubit,
        orderId: 'ord-server-123',
      )));
      await tester.pump(const Duration(milliseconds: 300));

      // The provided cubit owns the state — server-derived instructions
      // render, proving the load-bearing single-watch path is untouched.
      expect(find.text('instapay@merchant'), findsOneWidget);
      cubit.cancel();
    });

    testWidgets('orderId without cubit resumes the status watch',
        (tester) async {
      await tester.pumpWidget(_harness(InstapayInstructionsPage(
        orderId: 'ord-rehydrated',
        paymentService: stub,
      )));
      await tester.pump(const Duration(milliseconds: 300));

      // No crash, no "session not found" dead-end: the page owns a
      // rehydrated cubit scoped to the order and the server watch is live.
      expect(find.text('Payment session not found'), findsNothing);
      expect(stub.watchController.hasListener, isTrue);

      // Disposing the page closes the owned cubit (cancelling its
      // watch timer) so the test's pending-timer invariant holds.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('neither cubit nor orderId keeps the legacy error body',
        (tester) async {
      await tester.pumpWidget(_harness(const InstapayInstructionsPage()));
      await tester.pump();

      expect(find.text('Payment session not found'), findsOneWidget);
    });
  });
}
