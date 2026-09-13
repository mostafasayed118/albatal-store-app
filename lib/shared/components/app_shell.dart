import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/storefront/presentation/cubit/cart_cubit.dart';
import '../extensions/build_context_x.dart';
import '../routing/app_routes.dart';
import '../services/connectivity_gate.dart';
import 'offline_banner.dart';

final class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.gate});
  final Widget child;
  final ConnectivityGate gate;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
        body: Column(children: [
          StreamBuilder<bool>(
              stream: gate.isOnline,
              initialData: gate.current,
              builder: (_, snapshot) => snapshot.data == false
                  ? OfflineBanner(
                      message: l10n.offlineBannerMessage,
                      retryLabel: l10n.retry,
                      onRetry: () => unawaited(gate.recheck()))
                  : const SizedBox.shrink()),
          Expanded(child: child),
        ]),
        bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
            builder: (_, cart) => NavigationBar(
                    selectedIndex: _index(GoRouterState.of(context).uri.path),
                    onDestinationSelected: (i) => context.go([
                          Routes.home,
                          Routes.categories,
                          Routes.cart,
                          Routes.wishlist,
                          Routes.profile
                        ][i]),
                    destinations: [
                      NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          selectedIcon: const Icon(Icons.home),
                          label: l10n.home),
                      NavigationDestination(
                          icon: const Icon(Icons.grid_view_outlined),
                          selectedIcon: const Icon(Icons.grid_view),
                          label: l10n.categories),
                      NavigationDestination(
                          icon: Badge(
                              isLabelVisible: cart.count > 0,
                              label: Text(cartBadgeLabel(cart.count)),
                              child: const Icon(Icons.shopping_bag_outlined)),
                          selectedIcon: Badge(
                              isLabelVisible: cart.count > 0,
                              label: Text(cartBadgeLabel(cart.count)),
                              child: const Icon(Icons.shopping_bag)),
                          label: l10n.cart),
                      NavigationDestination(
                          icon: const Icon(Icons.favorite_border),
                          selectedIcon: const Icon(Icons.favorite),
                          label: l10n.wishlist),
                      NavigationDestination(
                          icon: const Icon(Icons.person_outline),
                          selectedIcon: const Icon(Icons.person),
                          label: l10n.profile),
                    ])));
  }

  int _index(String p) {
    if (p.startsWith(Routes.categories)) return 1;
    if (p.startsWith(Routes.cart)) return 2;
    if (p.startsWith(Routes.wishlist)) return 3;
    if (p.startsWith(Routes.profile)) return 4;
    return 0;
  }
}

/// Badge text for the cart count.
///
/// Caps at '99+' (UX-046) so the badge never blows out of shape at
/// triple-digit quantities.
String cartBadgeLabel(int count) => count > 99 ? '99+' : '$count';
