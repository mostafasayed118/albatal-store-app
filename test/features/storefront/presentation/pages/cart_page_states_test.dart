import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/cart_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _product = Product(
  id: 'silk-01',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money.egp(1290),
  imageColor: 0xFF176B57,
  stock: {'Emerald-2m': 8},
);

final class _CartRepo implements CartRepository {
  _CartRepo({this.items = const [], this.failRead = false});

  List<CartItem> items;
  bool failRead;

  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      failRead
          ? const Failure(AppError('cart store unavailable'))
          : Success(List.of(items));

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async {
    this.items = List.of(items);
    return const Success(null);
  }
}

Widget _app(GoRouter router, CartCubit cart) => BlocProvider.value(
      value: cart,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );

GoRouter _router(CartCubit cart) => GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
        GoRoute(
          path: '/catalog',
          builder: (_, __) => const Scaffold(body: Text('Catalog stub')),
        ),
        GoRoute(
          path: '/checkout',
          builder: (_, __) => const Scaffold(body: Text('Checkout stub')),
        ),
      ],
    );

void main() {
  testWidgets('a failed cart load offers Retry and recovers to the empty view',
      (tester) async {
    final repo = _CartRepo(failRead: true);
    final cart = CartCubit(repo);
    addTearDown(cart.close);
    await cart.restore();
    expect(cart.state.status, CartStatus.error);

    await tester.pumpWidget(_app(_router(cart), cart));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);

    repo.failRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(cart.state.status, CartStatus.ready);
    expect(find.text('Your cart is waiting for something exquisite.'),
        findsOneWidget);
  });

  testWidgets('the empty cart CTA routes back to the catalog', (tester) async {
    final repo = _CartRepo();
    final cart = CartCubit(repo);
    addTearDown(cart.close);
    await cart.restore();

    await tester.pumpWidget(_app(_router(cart), cart));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start shopping'));
    await tester.pumpAndSettle();

    expect(find.text('Catalog stub'), findsOneWidget);
  });

  testWidgets('a filled cart shows the tile and proceeds to checkout',
      (tester) async {
    final repo = _CartRepo(
      items: const [
        CartItem(
          product: _product,
          color: 'Emerald',
          length: '2m',
          quantity: 1,
        ),
      ],
    );
    final cart = CartCubit(repo);
    addTearDown(cart.close);
    await cart.restore();

    await tester.pumpWidget(_app(_router(cart), cart));
    await tester.pumpAndSettle();

    expect(find.text('Royal Emerald Silk'), findsOneWidget);

    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout stub'), findsOneWidget);
  });
}
