import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/checkout_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/order_success_page.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/payment_method_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/memory_storefront_persistence.dart';

const _testAddress = Address(
  id: 'addr-1',
  recipient: 'Ahmed Mansour',
  line: '12 El Tahrir St',
  city: 'Cairo',
  country: 'Egypt',
);

class _StubAddrRepo implements AddressRepository {
  final List<Address> addresses;
  _StubAddrRepo(this.addresses);
  @override
  Future<Result<List<Address>>> read() async => Success(addresses);
  @override
  Future<Result<void>> save(List<Address> addrs) async => const Success(null);
}

class _StubCheckoutRepo implements CheckoutRepository {
  // ignore: unused_element_parameter
  _StubCheckoutRepo({this.shouldFail = false});
  final bool shouldFail;
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    if (shouldFail) return const Failure(AppError('Checkout failed'));
    final subtotal = items.fold(
        Money.zero, (Money v, CartItem i) => v + i.product.price * i.quantity);
    return Success(PendingOrder(
      orderId: 'ORD-STUB-1',
      subtotal: subtotal,
      shipping: const Money.egp(75),
      total: subtotal + const Money.egp(75),
      expiresAt: DateTime(2026, 12, 31),
    ));
  }
}

CheckoutCubit _seededPendingCubit() {
  final cubit = CheckoutCubit(_StubCheckoutRepo());
  // Use dynamic to bypass @protected emit for test seeding — final class cannot be subclassed.
  (cubit as dynamic).emit(CheckoutState(
    status: CheckoutStatus.success,
    pendingOrderId: 'ORD-STUB-1',
    serverSubtotal: const Money.egp(100),
    serverShipping: const Money.egp(75),
    serverTotal: const Money.egp(175),
    selectedAddress: _testAddress,
  ));
  return cubit;
}

class _StubPayService implements PaymentService {
  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async =>
      const PaymentPending(
          checkoutUrl:
              'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=t');
  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async =>
      const PaymentFailed(message: 'stub');
  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) async =>
      const PaymentFailed(message: 'stub');

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream.empty();
}

Widget _checkoutHarness({
  AddressRepository? addrRepo,
  CheckoutRepository? checkoutRepo,
  CheckoutCubit? checkoutCubit,
  MemoryStorefrontPersistence? persistence,
}) {
  final store = persistence ?? MemoryStorefrontPersistence();
  final cart = CartCubit(store)
    ..add(products.first, color: 'Emerald', length: '2m', quantity: 1);
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cart),
        BlocProvider(create: (_) => WishlistCubit(store)),
        BlocProvider(create: (_) => OrdersCubit(store)),
        BlocProvider(
            create: (_) => AddressesCubit(addrRepo ?? _StubAddrRepo(const []))),
      ],
      child: CheckoutPage(
          checkoutRepository: checkoutRepo ?? _StubCheckoutRepo(),
          checkoutCubit: checkoutCubit),
    ),
  );
}

Widget _checkoutWithAddressHarness() =>
    _checkoutHarness(addrRepo: _StubAddrRepo(const [_testAddress]));

void main() {
  group('Task 5 — Checkout Stitch reskin (3528 flow)', () {
    testWidgets(
        'ListView uses EdgeInsetsDirectional padding.all(16) and Shipping Address Card is surface/outlineVariant 16 clipAntiAlias',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_checkoutWithAddressHarness());
      await tester.pump();

      // ListView padding must be EdgeInsetsDirectional.
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.padding, isA<EdgeInsetsDirectional>(),
          reason: 'Checkout ListView must use EdgeInsetsDirectional for RTL');
      expect(listView.padding, const EdgeInsetsDirectional.all(16));

      // Shipping Address Card: Card with surface + outlineVariant 1dp radius 16 clipAntiAlias wrapping the address picker.
      // Find the first Card that contains the shipping address title and AddressPicker descendants.
      final shippingCard = tester.widget<Card>(find.byType(Card).first);
      // Card should carry Stitch tokens surface + outlineVariant border radius 16.
      final scheme =
          Theme.of(tester.element(find.byType(Card).first)).colorScheme;
      expect(shippingCard.color, scheme.surface,
          reason: 'Shipping Card surface should be scheme.surface');
      final shape = shippingCard.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(16)));
      expect(shape.side.color, scheme.outlineVariant);
      expect(shape.side.width, 1);
      expect(shippingCard.clipBehavior, Clip.antiAlias);
    });

    testWidgets(
        'Server-confirmed totals Card appears after hasPendingOrder with surface outlineVariant 16 titleSmall and 8dp labelRows',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final seeded = _seededPendingCubit();
      await tester.pumpWidget(_checkoutHarness(
          checkoutCubit: seeded,
          addrRepo: _StubAddrRepo(const [_testAddress])));
      await tester.pump();

      // Should now show Server-confirmed totals card.
      expect(find.text('Server-confirmed totals'), findsOneWidget);
      // Title uses titleSmall.
      final title = tester.widget<Text>(find.text('Server-confirmed totals'));
      expect(
          title.style?.fontSize,
          Theme.of(tester.element(find.text('Server-confirmed totals')))
              .textTheme
              .titleSmall
              ?.fontSize);

      // The card wrapping server totals should be surface/outlineVariant 16.
      // Locate the Card ancestor of the title.
      final card = tester.widget<Card>(
        find.ancestor(
            of: find.text('Server-confirmed totals'),
            matching: find.byType(Card)),
      );
      final scheme =
          Theme.of(tester.element(find.byType(Card).first)).colorScheme;
      expect(card.color, scheme.surface);
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(16)));
      expect(shape.side.color, scheme.outlineVariant);
      expect(shape.side.width, 1);
    });

    testWidgets(
        'bottomNavigationBar is auto-height Container EdgeInsetsDirectional.all(16) surface with FilledButton 50px secondary #904D00 controlRadius 8 labelLarge proceedToPayment and hasAddress guard',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_checkoutWithAddressHarness());
      await tester.pump();

      // Auto-height bar (fits the 50px DESIGN CTA): no fixed-height
      // Container constrains the bottom bar anymore.
      expect(
        find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxHeight == 72),
        findsNothing,
        reason: 'Bottom bar must not pin the legacy fixed 72px height',
      );
      // Padding should be EdgeInsetsDirectional.all(16).
      final containerWithPadding = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.padding == const EdgeInsetsDirectional.all(16)),
      );
      expect(containerWithPadding.padding, isA<EdgeInsetsDirectional>());
      expect(containerWithPadding.padding, const EdgeInsetsDirectional.all(16));

      // Background should be surface.
      final boxDeco = containerWithPadding.decoration as BoxDecoration?;
      final scaffoldCtx = tester.element(find.byType(Scaffold));
      final scheme = Theme.of(scaffoldCtx).colorScheme;
      expect(boxDeco?.color, scheme.surface);

      // FilledButton inside should be secondary #904D00 and controlRadius 8.
      final button =
          tester.widget<FilledButton>(find.byType(FilledButton).last);
      expect(button.style?.backgroundColor?.resolve(const {}),
          const Color(0xFF904D00));
      final shape =
          button.style?.shape?.resolve(const {}) as RoundedRectangleBorder?;
      expect(shape?.borderRadius, const BorderRadius.all(Radius.circular(8)));
      // DESIGN CTA contract: 50px minimum touch height.
      expect(button.style?.minimumSize?.resolve(const {})?.height, 50);

      // Guard: onPressed disabled when no address? In this harness we have address, so should be enabled initially (before creating).
      // Now test guard after clearing address.
      final ctx = tester.element(find.byType(ListView));
      ctx.read<CheckoutCubit>().clearAddress();
      await tester.pump();
      final buttonAfterClear =
          tester.widget<FilledButton>(find.byType(FilledButton).last);
      expect(buttonAfterClear.onPressed, isNull,
          reason: 'CTA should be disabled without address (hasAddress guard)');
    });

    testWidgets('PaymentMethodPage CTA uses secondary #904D00 if present',
        (tester) async {
      final cubit = PaymentCubit(_StubPayService())
        ..initPayment(amount: const Money.egp(100), orderId: 'ord-123');
      final cart = CartCubit(MemoryStorefrontPersistence());
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cart,
          child: PaymentMethodPage(
            paymentCubit: cubit,
            args: const {
              'orderId': 'ord-123',
              'total': Money.egp(100),
              'customerEmail': 'a@b.c',
            },
          ),
        ),
      ));
      await tester.pump();

      final buttons = find.byType(FilledButton);
      expect(buttons, findsOneWidget);
      final btn = tester.widget<FilledButton>(buttons.first);
      final bg = btn.style?.backgroundColor?.resolve(const {});
      expect(bg, const Color(0xFF904D00),
          reason: 'PaymentMethodPage CTA should use secondary #904D00');
      await cubit.close();
      await cart.close();
    });
  });

  group('Task 5 — OrderSuccess Stitch confirmation', () {
    testWidgets(
        'shows CircleAvatar radius 48 primary with check and retains empty-id error branch',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OrderSuccessPage(orderId: 'ORD-2026-0001'),
      ));
      await tester.pump();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 48);
      expect(
          avatar.backgroundColor,
          Theme.of(tester.element(find.byType(CircleAvatar)))
              .colorScheme
              .primary);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Empty-id branch.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OrderSuccessPage(orderId: ''),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    test('AppTheme light/dark scaffold tokens are Stitch-exact', () {
      expect(AppTheme.light().scaffoldBackgroundColor.toARGB32(), 0xFFF9F9F9);
      expect(AppTheme.dark().scaffoldBackgroundColor.toARGB32(), 0xFF121212);
      expect(AppTheme.dark().cardColor.toARGB32(), 0xFF1E293B);
    });
  });
}
