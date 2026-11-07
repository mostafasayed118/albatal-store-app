import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/storefront/presentation/cubit/cart_cubit.dart';
import '../../features/storefront/presentation/cubit/wishlist_cubit.dart';
import '../extensions/build_context_x.dart';
import '../layout/breakpoints.dart';
import '../routing/app_routes.dart';
import '../services/connectivity_gate.dart';
import 'offline_banner.dart';
import 'responsive_shell.dart';

final class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.gate});
  final Widget child;
  final ConnectivityGate gate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocSelector<CartCubit, CartState, int>(
        selector: (cart) => cart.count,
        builder: (_, cartCount) =>
            BlocSelector<WishlistCubit, WishlistState, int>(
                selector: (wishlist) => wishlist.ids.length,
                builder: (_, wishlistCount) {
                  final index = _index(GoRouterState.of(context).uri.path);
                  // Count-scoped selectors: the navigation chrome rebuilds only
                  // when a badge number actually changes (audit perf note), and
                  // the wishlist badge reflects WishlistCubit live.
                  final List<({Widget icon, Widget selectedIcon, String label})>
                      destinations = [
                    (
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: l10n.home,
                    ),
                    (
                      icon: const Icon(Icons.grid_view_outlined),
                      selectedIcon: const Icon(Icons.grid_view),
                      label: l10n.categories,
                    ),
                    (
                      icon: Badge(
                          isLabelVisible: cartCount > 0,
                          label: Text(cartBadgeLabel(cartCount)),
                          child: const Icon(Icons.shopping_bag_outlined)),
                      selectedIcon: Badge(
                          isLabelVisible: cartCount > 0,
                          label: Text(cartBadgeLabel(cartCount)),
                          child: const Icon(Icons.shopping_bag)),
                      label: l10n.cart,
                    ),
                    (
                      icon: Badge(
                          isLabelVisible: wishlistCount > 0,
                          label: Text(cartBadgeLabel(wishlistCount)),
                          child: const Icon(Icons.favorite_border)),
                      selectedIcon: Badge(
                          isLabelVisible: wishlistCount > 0,
                          label: Text(cartBadgeLabel(wishlistCount)),
                          child: const Icon(Icons.favorite)),
                      label: l10n.wishlist,
                    ),
                    (
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(Icons.person),
                      label: l10n.profile,
                    ),
                  ];

                  final body = _ShellBody(gate: gate, child: child);

                  if (usesNavigationRail(context)) {
                    return Scaffold(
                      body: Row(
                        children: [
                          SafeArea(
                            right: false,
                            child: NavigationRail(
                              selectedIndex: index,
                              onDestinationSelected: (i) => _go(context, i),
                              labelType: NavigationRailLabelType.all,
                              // A short landscape window cannot fit five
                              // labelled destinations; let the rail scroll
                              // instead of overflowing.
                              scrollable: true,
                              destinations: [
                                for (final d in destinations)
                                  NavigationRailDestination(
                                    icon: d.icon,
                                    selectedIcon: d.selectedIcon,
                                    label: Text(d.label),
                                  ),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: body),
                        ],
                      ),
                    );
                  }

                  return Scaffold(
                    body: body,
                    bottomNavigationBar: NavigationBar(
                      selectedIndex: index,
                      onDestinationSelected: (i) => _go(context, i),
                      destinations: [
                        for (final d in destinations)
                          NavigationDestination(
                            icon: d.icon,
                            selectedIcon: d.selectedIcon,
                            label: d.label,
                          ),
                      ],
                    ),
                  );
                }));
  }

  void _go(BuildContext context, int i) => context.go([
        Routes.home,
        Routes.categories,
        Routes.cart,
        Routes.wishlist,
        Routes.profile,
      ][i]);

  int _index(String p) {
    if (p.startsWith(Routes.categories)) return 1;
    if (p.startsWith(Routes.cart)) return 2;
    if (p.startsWith(Routes.wishlist)) return 3;
    if (p.startsWith(Routes.profile)) return 4;
    return 0;
  }
}

/// Offline banner + routed page, shared by the bar and rail shells.
final class _ShellBody extends StatelessWidget {
  const _ShellBody({required this.gate, required this.child});

  final ConnectivityGate gate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(children: [
      StreamBuilder<bool>(
          stream: gate.isOnline,
          initialData: gate.current,
          builder: (_, snapshot) => snapshot.data == false
              ? OfflineBanner(
                  message: l10n.offlineBannerMessage,
                  retryLabel: l10n.retry,
                  onRetry: () => unawaited(gate.recheck()))
              : const SizedBox.shrink()),
      // Cap routed tabs on tablet/desktop; phones are unaffected.
      Expanded(child: ResponsiveShell(child: child)),
    ]);
  }
}

/// Badge text for the bottom-nav count badges (cart + wishlist).
///
/// Caps at '99+' (UX-046) so the badge never blows out of shape at
/// triple-digit quantities.
String cartBadgeLabel(int count) => count > 99 ? '99+' : '$count';
