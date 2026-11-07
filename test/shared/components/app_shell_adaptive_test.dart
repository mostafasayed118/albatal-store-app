import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_shell.dart';
import 'package:al_batal_elite/shared/routing/app_routes.dart';
import 'package:al_batal_elite/shared/services/connectivity_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class _CartRepository implements CartRepository {
  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      const Success([]);

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async =>
      const Success(null);
}

final class _WishlistRepository implements WishlistRepository {
  @override
  Future<Result<Set<String>>> readWishlist() async => const Success({});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async =>
      const Success(null);
}

/// Mounts the real shell over the real router for a given window size.
Future<({GoRouter router, CartCubit cart, WishlistCubit wishlist})> _pump(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cart = CartCubit(_CartRepository());
  final wishlist = WishlistCubit(_WishlistRepository());
  addTearDown(() async {
    await cart.close();
    await wishlist.close();
  });

  final router = GoRouter(initialLocation: Routes.home, routes: [
    ShellRoute(
      builder: (_, __, child) =>
          AppShell(gate: ConnectivityGate(), child: child),
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: Routes.categories,
          builder: (_, __) => const Scaffold(body: Text('categories')),
        ),
        GoRoute(
          path: Routes.cart,
          builder: (_, __) => const Scaffold(body: Text('cart')),
        ),
        GoRoute(
          path: Routes.wishlist,
          builder: (_, __) => const Scaffold(body: Text('wishlist')),
        ),
        GoRoute(
          path: Routes.profile,
          builder: (_, __) => const Scaffold(body: Text('profile')),
        ),
      ],
    ),
  ]);
  addTearDown(router.dispose);

  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: cart),
      BlocProvider.value(value: wishlist),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  await tester.pump();
  return (router: router, cart: cart, wishlist: wishlist);
}

void main() {
  testWidgets('wide window uses a NavigationRail and it navigates',
      (tester) async {
    final harness = await _pump(tester, const Size(840, 600));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path,
        Routes.categories);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('phone window keeps the bottom NavigationBar', (tester) async {
    final harness = await _pump(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path,
        Routes.wishlist);
  });

  testWidgets('short landscape rail window scrolls instead of overflowing',
      (tester) async {
    await _pump(tester, const Size(840, 360));

    expect(find.byType(NavigationRail), findsOneWidget);
    // The rail must scroll rather than overflow when the height cannot fit
    // five labelled destinations.
    expect(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
