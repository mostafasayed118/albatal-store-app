import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
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
  _CartRepo({this.items = const []});

  List<CartItem> items;

  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      Success(List.of(items));

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async {
    this.items = List.of(items);
    return const Success(null);
  }
}

/// The cart page's `buildWhen` skips rebuilds for same-status emissions that
/// only mirror the premium flag or the item list. This pins the
/// same-status / same-premium / different-items path: the row must appear.
void main() {
  testWidgets('adding an item rebuilds the cart without a status change',
      (tester) async {
    final repo = _CartRepo();
    final cart = CartCubit(repo);
    addTearDown(cart.close);
    await cart.restore();
    expect(cart.state.status, CartStatus.ready);

    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
        GoRoute(
          path: '/catalog',
          builder: (_, __) => const Scaffold(body: Text('Catalog stub')),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: cart,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Royal Emerald Silk'), findsNothing);

    // Same status (ready) and same premium flag, different item list.
    cart.add(_product);
    await tester.pumpAndSettle();

    expect(cart.state.status, CartStatus.ready);
    expect(cart.state.isPremiumMember, isFalse);
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
  });

  testWidgets('the premium-flag mirror rebuilds the cart too', (tester) async {
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

    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
        GoRoute(
          path: '/catalog',
          builder: (_, __) => const Scaffold(body: Text('Catalog stub')),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: cart,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    cart.setPremiumMember(isPremium: true);
    await tester.pumpAndSettle();

    expect(cart.state.isPremiumMember, isTrue);
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
  });
}
