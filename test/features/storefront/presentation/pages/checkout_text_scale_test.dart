import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/checkout_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_card.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/status_progress.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';
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
  const _StubCheckoutRepo();
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? couponCode,
    String? idempotencyKey,
  }) async {
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

/// Same provider set as the checkout page harness (stitch_checkout_test.dart),
/// with the page subtree pinned to a fixed 1.4× system text scale.
Widget _checkoutHarness() {
  final store = MemoryStorefrontPersistence();
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
            create: (_) => AddressesCubit(_StubAddrRepo([_testAddress]))),
      ],
      child: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: CheckoutPage(checkoutRepository: _StubCheckoutRepo()),
      ),
    ),
  );
}

Order _activeOrder() => Order(
      id: 'ORD-SCALE-1',
      items: [
        CartItem(
          product: products.first,
          color: 'Emerald',
          length: '1m',
          quantity: 1,
        ),
      ],
      subtotal: const Money.egp(1290),
      shipping: const Money.egp(75),
      total: const Money.egp(1365),
      status: OrderStatus.placed,
      placedAt: DateTime(2026, 9, 1),
      paymentMethod: 'cod',
    );

void main() {
  testWidgets(
      'Checkout page renders stepper, review section and totals without '
      'overflow at a 360dp phone viewport with 1.4 system font scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_checkoutHarness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);

    // Stepper still shows all three stages at scale.
    expect(find.text('Shipping Address'), findsWidgets);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Review Order'), findsWidgets);
  });

  testWidgets(
      'OrderCard with the status timeline renders without overflow at '
      '1.4 scale in a 360dp-wide column', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsetsDirectional.all(16),
              children: [
                OrderCard(
                  order: _activeOrder(),
                  isCompleted: false,
                  scheme: Theme.of(context).colorScheme,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Active order → the ● ○ ○ ○ status timeline is present.
    expect(find.byType(StatusProgress), findsOneWidget);
    expect(find.textContaining('Placed'), findsWidgets);
    expect(find.textContaining('Delivered'), findsOneWidget);
  });
}
