import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/entities/address.dart';
import '../../core/error/result.dart';
import '../../features/addresses/data/supabase_address_repository.dart';
import '../../features/addresses/domain/repositories/address_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/storefront/data/local_cart_repository.dart';
import '../../features/storefront/data/local_orders_repository.dart';
import '../../features/storefront/data/local_wishlist_repository.dart';
import '../../features/storefront/data/storefront_persistence.dart';
import '../../features/storefront/data/supabase_cart_repository.dart';
import '../../features/storefront/data/supabase_orders_repository.dart';
import '../../features/storefront/data/supabase_wishlist_repository.dart';
import '../../features/storefront/domain/repositories/cart_repository.dart';
import '../../features/storefront/domain/repositories/orders_repository.dart';
import '../../features/storefront/domain/repositories/wishlist_repository.dart';
import '../services/service_locator.dart';

/// Simple InheritedWidget that provides repositories based on auth state.
class AuthAwareRepositoryProvider extends InheritedWidget {
  const AuthAwareRepositoryProvider({
    super.key,
    required this.cartRepo,
    required this.wishlistRepo,
    required this.ordersRepo,
    required this.addressRepo,
    required super.child,
  });

  final CartRepository cartRepo;
  final WishlistRepository wishlistRepo;
  final OrdersRepository ordersRepo;
  final AddressRepository addressRepo;

  static AuthAwareRepositoryProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthAwareRepositoryProvider>()!;
  }

  @override
  bool updateShouldNotify(AuthAwareRepositoryProvider oldWidget) =>
      cartRepo != oldWidget.cartRepo ||
      wishlistRepo != oldWidget.wishlistRepo ||
      ordersRepo != oldWidget.ordersRepo ||
      addressRepo != oldWidget.addressRepo;
}

/// Creates the correct repositories based on auth state and wraps the app.
class AuthAwareRepositoryScope extends StatelessWidget {
  const AuthAwareRepositoryScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final persistence = LocalStorefrontPersistence(getIt<SharedPreferences>());
        final isAuth = authState.isAuthenticated;

        return AuthAwareRepositoryProvider(
          cartRepo: isAuth
              ? SupabaseCartRepository()
              : LocalCartRepository(persistence),
          wishlistRepo: isAuth
              ? SupabaseWishlistRepository()
              : LocalWishlistRepository(persistence),
          ordersRepo: isAuth
              ? SupabaseOrdersRepository()
              : LocalOrdersRepository(persistence),
          addressRepo: isAuth
              ? SupabaseAddressRepository()
              : _GuestAddressRepository(),
          child: child,
        );
      },
    );
  }
}

class _GuestAddressRepository implements AddressRepository {
  @override
  Future<Result<List<Address>>> read() async => const Success([]);
  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}
