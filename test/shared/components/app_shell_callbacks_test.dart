import 'dart:async';

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

final class _OfflineGate implements ConnectivityGate {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  int rechecks = 0;

  @override
  bool get current => false;

  @override
  Stream<bool> get isOnline => _controller.stream;

  @override
  Future<void> recheck() async {
    rechecks++;
    _controller.add(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

void main() {
  testWidgets('offline retry and bottom-nav taps reach their callbacks',
      (tester) async {
    final gate = _OfflineGate();
    final cart = CartCubit(_CartRepository());
    final wishlist = WishlistCubit(_WishlistRepository());
    addTearDown(() async {
      await gate._controller.close();
      await cart.close();
      await wishlist.close();
    });

    final router = GoRouter(initialLocation: Routes.home, routes: [
      ShellRoute(
        builder: (_, __, child) => AppShell(gate: gate, child: child),
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

    // Offline banner + its Retry callback (the gate re-probe).
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(gate.rechecks, 1);

    // Category destination -> context.go through the callback list.
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.categories);

    // Profile destination (the last entry in the callback's route list).
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.profile);
  });
}
