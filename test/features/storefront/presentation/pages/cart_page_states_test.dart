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
  bool failWrite = false;
  int writes = 0;

  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      failRead
          ? const Failure(AppError('cart store unavailable'))
          : Success(List.of(items));

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async {
    writes++;
    if (failWrite) return const Failure(AppError('cart store unavailable'));
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

  testWidgets('retrying a persist error keeps the live cart items',
      (tester) async {
    // The persisted cart is stale/empty while the live cart holds the
    // user's selection; its write failed, so status is error but items
    // stay on screen. Retry must never overwrite them with the stale
    // persisted cart.
    final repo = _CartRepo();
    final cart = CartCubit(repo);
    addTearDown(cart.close);
    await cart.restore();

    await tester.pumpWidget(_app(_router(cart), cart));
    await tester.pumpAndSettle();
    expect(find.text('Start shopping'), findsOneWidget);

    repo.failWrite = true;
    cart.add(_product);
    await tester.pumpAndSettle();
    expect(cart.state.status, CartStatus.error);
    expect(cart.state.items, hasLength(1));
    expect(find.text('Something went wrong'), findsOneWidget);

    repo.failWrite = false;
    final writesBeforeRetry = repo.writes;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(cart.state.items, hasLength(1));
    expect(cart.state.status, CartStatus.ready);
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    // The retry must re-attempt the failed WRITE (not just re-read), so the
    // live cart is durable after the UI reports ready.
    expect(repo.writes, writesBeforeRetry + 1);
    expect(repo.items, hasLength(1));
  });

  testWidgets('a failed persist retry keeps the cart in error with its items',
      (tester) async {
    final repo = _CartRepo();
    final cart = CartCubit(repo);
    addTearDown(cart.close);
    await cart.restore();

    await tester.pumpWidget(_app(_router(cart), cart));
    await tester.pumpAndSettle();

    repo.failWrite = true;
    cart.add(_product);
    await tester.pumpAndSettle();
    expect(cart.state.status, CartStatus.error);

    final writesBeforeRetry = repo.writes;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Still failing: the UI must not claim ready, and the live items stay.
    expect(repo.writes, writesBeforeRetry + 1);
    expect(cart.state.status, CartStatus.error);
    expect(cart.state.items, hasLength(1));
    expect(find.text('Something went wrong'), findsOneWidget);
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
