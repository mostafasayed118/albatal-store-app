import 'dart:async';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_shell.dart';
import 'package:al_batal_elite/shared/services/connectivity_gate.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Regression for the device-found bug (2026-09-13): heart taps updated
/// the wishlist but the bottom-nav wishlist tab showed no count — the
/// destination had no badge wired at all. The shell now mirrors the
/// cart badge for the wishlist via WishlistCubit.
class _StubCartRepository implements CartRepository {
  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      const Success([]);

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async =>
      const Success(null);
}

class _StubWishlistRepository implements WishlistRepository {
  _StubWishlistRepository(this._ids);
  final Set<String> _ids;

  @override
  Future<Result<Set<String>>> readWishlist() async => Success({..._ids});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async =>
      const Success(null);
}

Widget _harness(WishlistCubit wishlist, CartCubit cart) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cart),
        BlocProvider.value(value: wishlist),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(routes: [
          ShellRoute(
            builder: (_, __, child) =>
                AppShell(gate: ConnectivityGate(), child: child),
            routes: [
              GoRoute(
                  path: '/',
                  builder: (_, __) =>
                      const Scaffold(body: Text('body content'))),
            ],
          ),
        ]),
      ),
    );

Iterable<Badge> visibleBadges(WidgetTester tester) =>
    tester.widgetList<Badge>(find.byType(Badge)).where((b) => b.isLabelVisible);

void main() {
  testWidgets('wishlist badge mirrors the wishlist count and updates live',
      (tester) async {
    final cart = CartCubit(_StubCartRepository());
    final wishlist = WishlistCubit(_StubWishlistRepository({'w1', 'w2'}));
    unawaited(wishlist.restore());
    addTearDown(() {
      cart.close();
      wishlist.close();
    });

    await tester.pumpWidget(_harness(wishlist, cart));
    await tester.pump();
    await tester.pump();

    // Seeded wishlist: badge shows 2; cart badge stays hidden (count 0).
    expect(find.text('2'), findsOneWidget);
    expect(visibleBadges(tester).length, 1);

    // The reported bug: a heart tap must move the badge immediately.
    wishlist.toggle('w3');
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(visibleBadges(tester).length, 1);
  });

  testWidgets('no badge when the wishlist is empty', (tester) async {
    final cart = CartCubit(_StubCartRepository());
    final wishlist = WishlistCubit(_StubWishlistRepository(const {}));
    unawaited(wishlist.restore());
    addTearDown(() {
      cart.close();
      wishlist.close();
    });

    await tester.pumpWidget(_harness(wishlist, cart));
    await tester.pump();

    expect(visibleBadges(tester), isEmpty);
  });
}
