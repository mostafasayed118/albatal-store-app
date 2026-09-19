import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/error/result.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/settings/domain/account_deletion_port.dart';
import '../features/storefront/presentation/cubit/cart_cubit.dart';
import '../features/storefront/presentation/cubit/wishlist_cubit.dart';

/// Composes the app-scoped `AuthCubit` / `CartCubit` / `WishlistCubit`
/// (all provided by `app.dart`'s MultiBlocProvider) into the settings
/// feature's [AccountDeletionPort].
///
/// Shared-layer adapter (audit 2026-09): `shared/` already imports every
/// feature for routing and smoke tests, so the cross-feature cubit types
/// are referenced here — never from the settings page itself. Cubit reads
/// run inside the route-builder's callbacks, so no widget rebuilds and
/// nothing needs watching.
final class SettingsAccountAdapter implements AccountDeletionPort {
  const SettingsAccountAdapter(this._context);

  final BuildContext _context;

  @override
  bool get isAuthenticated => _context.read<AuthCubit>().state.isAuthenticated;

  @override
  Future<Result<void>> deleteAccount({required String email}) =>
      _context.read<AuthCubit>().deleteAccount(email: email);

  @override
  void clearGuestData() {
    _context.read<CartCubit>().clear();
    _context.read<WishlistCubit>().clearAll();
  }
}
