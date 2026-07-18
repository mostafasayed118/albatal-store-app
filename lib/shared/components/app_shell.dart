import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/storefront/presentation/cubit/storefront_cubits.dart';
import '../extensions/build_context_x.dart';

final class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
        body: child,
        bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
            builder: (_, cart) => NavigationBar(
                    selectedIndex: _index(GoRouterState.of(context).uri.path),
                    onDestinationSelected: (i) => context.go([
                          '/home',
                          '/categories',
                          '/cart',
                          '/wishlist',
                          '/profile'
                        ][i]),
                    destinations: [
                      NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          selectedIcon: const Icon(Icons.home),
                          label: l.home),
                      NavigationDestination(
                          icon: const Icon(Icons.grid_view_outlined),
                          selectedIcon: const Icon(Icons.grid_view),
                          label: l.categories),
                      NavigationDestination(
                          icon: Badge(
                              isLabelVisible: cart.count > 0,
                              label: Text('${cart.count}'),
                              child: const Icon(Icons.shopping_bag_outlined)),
                          selectedIcon: Badge(
                              isLabelVisible: cart.count > 0,
                              label: Text('${cart.count}'),
                              child: const Icon(Icons.shopping_bag)),
                          label: l.cart),
                      NavigationDestination(
                          icon: const Icon(Icons.favorite_border),
                          selectedIcon: const Icon(Icons.favorite),
                          label: l.wishlist),
                      NavigationDestination(
                          icon: const Icon(Icons.person_outline),
                          selectedIcon: const Icon(Icons.person),
                          label: l.profile)
                    ])));
  }
  int _index(String p) {
    if (p.startsWith('/categories')) return 1;
    if (p.startsWith('/cart')) return 2;
    if (p.startsWith('/wishlist')) return 3;
    if (p.startsWith('/profile')) return 4;
    return 0;
  }
}
