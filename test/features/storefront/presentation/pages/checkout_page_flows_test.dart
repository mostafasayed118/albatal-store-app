import 'dart:async';

import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/auth_session_port.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/checkout_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

final class _AddressRepo implements AddressRepository {
  _AddressRepo(this.addresses);

  final List<Address> addresses;

  @override
  Future<Result<List<Address>>> read() async => Success(addresses);

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

final class _AuthSession implements AuthSessionPort {
  const _AuthSession(this.email);

  final String? email;

  @override
  String? currentUserEmail() => email;
}

PendingOrder _order() => PendingOrder(
      orderId: 'ORD-STUB-1',
      subtotal: const Money.egp(2580),
      shipping: const Money.egp(75),
      total: const Money.egp(2655),
      expiresAt: DateTime.utc(2026, 10, 21, 12),
    );

final class _SuccessCheckout implements CheckoutRepository {
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Address? address,
    String? couponCode,
    String? idempotencyKey,
  }) async =>
      Success(_order());
}

final class _FailingCheckout implements CheckoutRepository {
  const _FailingCheckout(this.error);

  final AppError error;

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Address? address,
    String? couponCode,
    String? idempotencyKey,
  }) async =>
      Failure(error);
}

final class _DelayedCheckout implements CheckoutRepository {
  final Completer<Result<PendingOrder>> completer =
      Completer<Result<PendingOrder>>();

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Address? address,
    String? couponCode,
    String? idempotencyKey,
  }) =>
      completer.future;
}

const _defaultAddress = Address(
  id: 'a1',
  recipient: 'Default Person',
  phone: '01012345678',
  line: '1 Main St',
  city: 'Cairo',
  country: 'EG',
  isDefault: true,
);

const _plainAddress = Address(
  id: 'a2',
  recipient: 'Plain Person',
  phone: '01087654321',
  line: '2 Side St',
  city: 'Giza',
  country: 'EG',
);

Widget _app(
  GoRouter router, {
  required CheckoutRepository checkoutRepository,
  required CartCubit cart,
  required AddressesCubit addresses,
}) {
  final persistence = MemoryStorefrontPersistence();
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: cart),
      BlocProvider(create: (_) => WishlistCubit(persistence)),
      BlocProvider(create: (_) => OrdersCubit(persistence)),
      BlocProvider.value(value: addresses),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

GoRouter _router(
  CheckoutRepository checkoutRepository, {
  AuthSessionPort? authSession,
  void Function(Map<String, dynamic> extra)? onPayment,
}) =>
    GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (_, __) => CheckoutPage(
            checkoutRepository: checkoutRepository,
            authSession: authSession,
          ),
        ),
        GoRoute(
          path: '/payment-method',
          builder: (_, s) {
            final extra = s.extra;
            if (extra is Map<String, dynamic>) onPayment?.call(extra);
            return const Scaffold(body: Text('Payment stub'));
          },
        ),
      ],
    );

void main() {
  testWidgets('successful checkout pushes payment with server totals + email',
      (tester) async {
    final persistence = MemoryStorefrontPersistence();
    final cart = CartCubit(persistence)
      ..add(products.first, color: 'Emerald', length: '2m', quantity: 2);
    final addresses = AddressesCubit(_AddressRepo(const [_defaultAddress]));
    Map<String, dynamic>? paymentExtra;

    await tester.pumpWidget(
      _app(
        _router(
          _SuccessCheckout(),
          authSession: const _AuthSession('shopper@example.test'),
          onPayment: (extra) => paymentExtra = extra,
        ),
        checkoutRepository: _SuccessCheckout(),
        cart: cart,
        addresses: addresses,
      ),
    );
    await addresses.load();
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Proceed to Payment'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Proceed to Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Payment stub'), findsOneWidget);
    expect(paymentExtra, isNotNull);
    expect(paymentExtra!['orderId'], 'ORD-STUB-1');
    expect(paymentExtra!['total'], const Money.egp(2655));
    expect(paymentExtra!['customerEmail'], 'shopper@example.test');
  });

  testWidgets('a non-default address is auto-selected as the first entry',
      (tester) async {
    final persistence = MemoryStorefrontPersistence();
    final cart = CartCubit(persistence)
      ..add(products.first, color: 'Emerald', length: '1m', quantity: 1);
    final addresses = AddressesCubit(_AddressRepo(const [_plainAddress]));

    await tester.pumpWidget(
      _app(
        _router(_SuccessCheckout()),
        checkoutRepository: _SuccessCheckout(),
        cart: cart,
        addresses: addresses,
      ),
    );
    await addresses.load();
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Proceed to Payment'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('Plain Person'), findsWidgets);
  });

  testWidgets('server-authored failure message reaches the snackbar',
      (tester) async {
    final persistence = MemoryStorefrontPersistence();
    final cart = CartCubit(persistence)
      ..add(products.first, color: 'Emerald', length: '1m', quantity: 1);
    final addresses = AddressesCubit(_AddressRepo(const [_defaultAddress]));

    await tester.pumpWidget(
      _app(
        _router(
          const _FailingCheckout(
            AppError('Server says no', code: 'server_side_code'),
          ),
        ),
        checkoutRepository: const _FailingCheckout(
          AppError('Server says no', code: 'server_side_code'),
        ),
        cart: cart,
        addresses: addresses,
      ),
    );
    await addresses.load();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proceed to Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Server says no'), findsOneWidget);
  });

  testWidgets('a coded checkout failure localizes the retry copy',
      (tester) async {
    final persistence = MemoryStorefrontPersistence();
    final cart = CartCubit(persistence)
      ..add(products.first, color: 'Emerald', length: '1m', quantity: 1);
    final addresses = AddressesCubit(_AddressRepo(const [_defaultAddress]));

    await tester.pumpWidget(
      _app(
        _router(
          const _FailingCheckout(
            AppError('raw english', code: kCheckoutFailedCode),
          ),
        ),
        checkoutRepository: const _FailingCheckout(
          AppError('raw english', code: kCheckoutFailedCode),
        ),
        cart: cart,
        addresses: addresses,
      ),
    );
    await addresses.load();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proceed to Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout failed. Please try again.'), findsOneWidget);
  });

  testWidgets('the empty-cart guard localizes instead of leaking English',
      (tester) async {
    final persistence = MemoryStorefrontPersistence();
    final cart = CartCubit(persistence);
    final addresses = AddressesCubit(_AddressRepo(const [_defaultAddress]));

    await tester.pumpWidget(
      _app(
        _router(_SuccessCheckout()),
        checkoutRepository: _SuccessCheckout(),
        cart: cart,
        addresses: addresses,
      ),
    );
    await addresses.load();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proceed to Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty. Add something exquisite first.'),
        findsOneWidget);
  });

  testWidgets('the CTA renders a spinner while the order is being created',
      (tester) async {
    final persistence = MemoryStorefrontPersistence();
    final cart = CartCubit(persistence)
      ..add(products.first, color: 'Emerald', length: '1m', quantity: 1);
    final addresses = AddressesCubit(_AddressRepo(const [_defaultAddress]));
    final repo = _DelayedCheckout();

    await tester.pumpWidget(
      _app(
        _router(repo),
        checkoutRepository: repo,
        cart: cart,
        addresses: addresses,
      ),
    );
    await addresses.load();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proceed to Payment'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Proceed to Payment'), findsNothing);

    repo.completer.complete(Success(_order()));
    await tester.pumpAndSettle();

    expect(find.text('Payment stub'), findsOneWidget);
  });
}
