import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/checkout_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class StubAddressRepository implements AddressRepository {
  @override
  Future<Result<List<Address>>> read() async => const Success([]);
  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

/// Stub CheckoutRepository — returns a fake pending order with
/// server-computed totals (subtotal, shipping, total).
class StubCheckoutRepository implements CheckoutRepository {
  StubCheckoutRepository({this.shouldFail = false, this.errorMessage});
  final bool shouldFail;
  final String? errorMessage;

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    if (shouldFail) {
      return Failure(AppError(errorMessage ?? 'Checkout failed'));
    }
    final subtotal = items.fold(
        Money.zero, (Money v, CartItem i) => v + i.product.price * i.quantity);
    const shipping = Money.egp(75);
    return Success(PendingOrder(
      orderId: 'ORD-STUB-1',
      subtotal: subtotal,
      shipping: shipping,
      total: subtotal + shipping,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    ));
  }
}

Widget _harness({StubCheckoutRepository? checkoutRepo}) {
  final persistence = MemoryStorefrontPersistence();
  final cart = CartCubit(persistence)
    ..add(products.first, color: 'Emerald', length: '2m', quantity: 2);
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cart),
        BlocProvider(create: (_) => WishlistCubit(persistence)),
        BlocProvider(create: (_) => OrdersCubit(persistence)),
        BlocProvider(create: (_) => AddressesCubit(StubAddressRepository())),
      ],
      child: CheckoutPage(
          checkoutRepository: checkoutRepo ?? StubCheckoutRepository()),
    ),
  );
}

void main() {
  testWidgets('checkout page shows step indicators and payment options',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    // Let the cart debounce timer (500ms) complete.
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Proceed to Payment'), findsOneWidget);
  });

  testWidgets('checkout page shows empty address state',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('No addresses saved yet'), findsOneWidget);
    expect(find.text('Add Address'), findsOneWidget);
  });

  testWidgets('checkout page shows cart summary', (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Scroll to bottom to find cart summary
    await tester.scrollUntilVisible(find.text('Total'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Shipping'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
  });
}
