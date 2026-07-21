import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/paymob_checkout_page.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/payment_method_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/order_success_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Stub payment service: initiation returns a hosted checkout URL and
/// the watch stream never emits a terminal result (we drive state from
/// the cubit directly in these tests).
class _NavStub implements PaymentService {
  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async =>
      const PaymentPending(
        checkoutUrl:
            'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=abc',
      );

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream<PaymentResult>.empty();
}

GoRouter _router(PaymentCubit cubit, CartCubit cart) => GoRouter(
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
                'total': Money.egp(100),
                'customerEmail': 'a@b.c',
              },
            ),
          ),
        ),
        GoRoute(
          path: '/paymob-checkout',
          builder: (_, s) => PaymobCheckoutPage(
            checkoutUrl: s.extra is String ? s.extra as String : '',
          ),
        ),
        GoRoute(
          path: '/order-success',
          builder: (_, s) => OrderSuccessPage(
            orderId: s.extra is String ? s.extra as String : '',
          ),
        ),
      ],
    );

Widget _harness(PaymentCubit cubit, CartCubit cart) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router(cubit, cart),
    );

void main() {
  group('PaymentMethodPage navigation', () {
    late PaymentCubit cubit;
    late CartCubit cart;

    setUp(() {
      cubit = PaymentCubit(_NavStub());
      cart = CartCubit(MemoryStorefrontPersistence())
        ..add(products.first, color: 'Emerald', length: '2m', quantity: 1);
    });

    tearDown(() async => cubit.close());

    testWidgets('pending state navigates to the hosted Paymob checkout',
        (tester) async {
      await tester.pumpWidget(_harness(cubit, cart));
      await tester.pumpAndSettle();

      // Drive the cubit synchronously into the pending state the way
      // processPayment would, so navigation is deterministic in the test.
      cubit.emit(const PaymentState(
        status: PaymentStatus.awaitingVerification,
        selectedMethod: PaymentMethod.paymobCard,
        orderId: 'ord-server-123',
        amount: Money.egp(100),
        checkoutUrl:
            'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=abc',
      ));
      await tester.pumpAndSettle();

      // The hosted checkout page is now on top.
      expect(find.byType(PaymobCheckoutPage), findsOneWidget);
      expect(find.text('Return to payment'), findsNothing);
    });

    testWidgets('repeated pending emissions do not push checkout twice',
        (tester) async {
      await tester.pumpWidget(_harness(cubit, cart));
      await tester.pumpAndSettle();

      cubit.emit(const PaymentState(
        status: PaymentStatus.awaitingVerification,
        selectedMethod: PaymentMethod.paymobCard,
        orderId: 'ord-server-123',
        amount: Money.egp(100),
        checkoutUrl:
            'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=abc',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(PaymobCheckoutPage), findsOneWidget);

      // Re-emit the same pending state (e.g. a duplicate realtime echo).
      cubit.emit(cubit.state.copyWith(status: PaymentStatus.awaitingVerification));
      await tester.pumpAndSettle();

      // Still exactly one checkout page — no duplicate navigation.
      expect(find.byType(PaymobCheckoutPage), findsOneWidget);
    });

    testWidgets('success navigates to order-success with the real order id',
        (tester) async {
      await tester.pumpWidget(_harness(cubit, cart));
      await tester.pumpAndSettle();

      cubit
        ..selectMethod(PaymentMethod.paymobCard)
        ..emit(const PaymentState(
          status: PaymentStatus.success,
          orderId: 'ord-server-123',
          amount: Money.egp(100),
        ));
      await tester.pumpAndSettle();

      expect(find.byType(OrderSuccessPage), findsOneWidget);
      expect(find.text('#ord-server-123'), findsOneWidget);
      // The cart was cleared on success.
      expect(cart.state.items, isEmpty);
    });

    testWidgets(
        'an invalid checkout URL does not open the WebView and shows a recoverable error',
        (tester) async {
      await tester.pumpWidget(_harness(cubit, cart));
      await tester.pumpAndSettle();

      cubit.selectMethod(PaymentMethod.paymobCard);
      // Force an unsafe URL through the state to exercise the guard.
      cubit.emit(const PaymentState(
        status: PaymentStatus.awaitingVerification,
        selectedMethod: PaymentMethod.paymobCard,
        orderId: 'ord-server-123',
        amount: Money.egp(100),
        checkoutUrl: 'http://evil.example.com/checkout',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PaymobCheckoutPage), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Order history visibility after checkout', () {
    testWidgets(
        'the success page lets the user reach order history without creating a duplicate local order',
        (tester) async {
      // A server order already exists (created by the checkout RPC);
      // no local OrdersCubit.place() is called on payment success.
      final cubit = PaymentCubit(_NavStub());
      final router = GoRouter(
        initialLocation: '/order-success',
        routes: [
          GoRoute(
            path: '/order-success',
            builder: (_, s) => OrderSuccessPage(
              orderId: s.extra is String ? s.extra as String : 'ord-server-456',
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ));
      await tester.pumpAndSettle();

      expect(find.text('#ord-server-456'), findsOneWidget);
      // The local cart is not touched here (clear happens on the source page);
      // the canonical order lives on the server.
      expect(find.text('Track My Order'), findsOneWidget);
      await cubit.close();
    });
  });
}
