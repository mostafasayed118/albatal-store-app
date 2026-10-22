import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/payment_method_page.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/paymob_checkout_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

class _MethodPageStub implements PaymentService {
  final PaymentResult initiateResult = const PaymentFailed(message: 'stub');
  int initiateCalls = 0;
  int codCalls = 0;

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async {
    initiateCalls++;
    return initiateResult;
  }

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async {
    codCalls++;
    return const PaymentSuccess(transactionId: 'cod-txn', amount: Money.zero);
  }

  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) async =>
      const PaymentSuccess(transactionId: '', amount: Money.zero);

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream<PaymentResult>.empty();

  @override
  Future<InstapayInitiation> initiateInstapayPayment(
          {required String orderId}) async =>
      const InstapayUnavailable(message: 'stub: not exercised');

  @override
  Future<PaymentResult> submitInstapayProof({
    required String orderId,
    required List<int> proofBytes,
    required String fileExt,
    String? reference,
  }) async =>
      const PaymentFailed(message: 'stub: not exercised');
}

const _args = {
  'orderId': 'ord-server-1',
  'total': Money.egp(100),
  'customerEmail': 'a@b.c',
};

Widget _harness({
  required PaymentCubit? cubit,
  PaymentService? service,
  required Map<String, dynamic> args,
  required CartCubit cart,
}) {
  final router = GoRouter(
    initialLocation: '/payment-method',
    routes: [
      GoRoute(
        path: '/payment-method',
        builder: (_, __) => BlocProvider.value(
          value: cart,
          child: PaymentMethodPage(
            paymentCubit: cubit,
            paymentService: service,
            args: args,
          ),
        ),
      ),
      GoRoute(
        path: '/paymob-checkout',
        builder: (_, s) => PaymobCheckoutPage(
          checkoutUrl: s.extra is String ? s.extra as String : '',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

CartCubit _cart() => CartCubit(MemoryStorefrontPersistence())
  ..add(products.first, color: 'Emerald', length: '2m', quantity: 1);

void main() {
  late _MethodPageStub service;
  late PaymentCubit cubit;
  late CartCubit cart;

  setUp(() {
    service = _MethodPageStub();
    cubit = PaymentCubit(service);
    cart = _cart();
  });

  tearDown(() async {
    await cubit.close();
  });

  Future<void> pump(WidgetTester tester,
      {Map<String, dynamic> args = _args}) async {
    await tester.pumpWidget(_harness(
      cubit: cubit,
      args: args,
      cart: cart,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('production path creates its own cubit and initiates payment',
      (tester) async {
    final ownService = _MethodPageStub();
    await tester.pumpWidget(_harness(
      cubit: null,
      service: ownService,
      args: _args,
      cart: cart,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay with Card'));
    await tester.pump();
    await tester.ensureVisible(find.text('Pay Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay Now'));
    await tester.pumpAndSettle();

    expect(ownService.initiateCalls, 1);
    expect(find.text('Payment failed. You can retry.'), findsOneWidget);
  });

  testWidgets('tapping each option updates the cubit selection',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Pay with Card'));
    await tester.pump();
    expect(cubit.state.selectedMethod, PaymentMethod.paymobCard);

    await tester.tap(find.text('Cash on Delivery'));
    await tester.pump();
    expect(cubit.state.selectedMethod, PaymentMethod.cashOnDelivery);

    await tester.tap(find.text('InstaPay'));
    await tester.pump();
    expect(cubit.state.selectedMethod, PaymentMethod.instapay);
  });

  testWidgets('missing order reference blocks payment', (tester) async {
    await pump(tester, args: const {
      'orderId': '   ',
      'total': Money.egp(100),
      'customerEmail': 'a@b.c',
    });

    expect(
      find.text('Unable to continue: the order reference is missing.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('success without an order reference only shows a snackbar',
      (tester) async {
    await pump(tester);

    cubit.emit(const PaymentState(
      status: PaymentStatus.success,
      selectedMethod: PaymentMethod.paymobCard,
      orderId: '',
      amount: Money.egp(100),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('Payment succeeded but the order reference is missing.'),
      findsOneWidget,
    );
    expect(find.byType(PaymentMethodPage), findsOneWidget);
  });

  for (final entry in const {
    PaymentStatus.failed: 'Payment failed. You can retry.',
    PaymentStatus.cancelled: 'Payment cancelled. You can retry.',
    PaymentStatus.expired: 'Payment expired. You can retry.',
    PaymentStatus.timedOut:
        'Payment verification timed out. Please check your orders before retrying.',
  }.entries) {
    testWidgets('${entry.key} shows the localized retry snackbar',
        (tester) async {
      await pump(tester);

      cubit.emit(PaymentState(
        status: entry.key,
        selectedMethod: PaymentMethod.paymobCard,
        orderId: 'ord-server-1',
        amount: const Money.egp(100),
      ));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('a failure while the hosted checkout is open pops it',
      (tester) async {
    await pump(tester);
    cubit.selectMethod(PaymentMethod.paymobCard);

    cubit.emit(const PaymentState(
      status: PaymentStatus.awaitingVerification,
      selectedMethod: PaymentMethod.paymobCard,
      orderId: 'ord-server-1',
      amount: Money.egp(100),
      checkoutUrl:
          'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=abc',
    ));
    await tester.pumpAndSettle();
    expect(find.byType(PaymobCheckoutPage), findsOneWidget);

    cubit.emit(const PaymentState(
      status: PaymentStatus.failed,
      selectedMethod: PaymentMethod.paymobCard,
      orderId: 'ord-server-1',
      amount: Money.egp(100),
      checkoutUrl:
          'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=abc',
    ));
    await tester.pumpAndSettle();

    expect(find.byType(PaymobCheckoutPage), findsNothing);
    expect(find.text('Payment failed. You can retry.'), findsOneWidget);
  });

  testWidgets('processing state shows a spinner and disables the pay button',
      (tester) async {
    await pump(tester);

    cubit.emit(const PaymentState(
      status: PaymentStatus.processing,
      selectedMethod: PaymentMethod.paymobCard,
      orderId: 'ord-server-1',
      amount: Money.egp(100),
    ));
    // Two frames: the bloc stream delivers on a microtask, then the spinner
    // frame renders. (pumpAndSettle would never settle on the spinner.)
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
