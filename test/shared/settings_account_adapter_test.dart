import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/shared/settings_account_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/stub_auth_repositories.dart';

final class _AuthRepository implements AuthRepository {
  final deletedEmails = <String>[];

  @override
  Future<Result<Authenticated?>> checkSession() async => const Success(null);

  @override
  Future<Result<AuthOutcome>> signUp(
          {required String email,
          required String password,
          String? fullName}) async =>
      const Success(ConfirmationRequired());

  @override
  Future<Result<Authenticated>> signIn(
          {required String email, required String password}) async =>
      const Failure(AppError('stub'));

  @override
  Future<Result<void>> resetPassword(String email) async => const Success(null);

  @override
  Future<Result<void>> updatePassword(String newPassword) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> deleteAccount({required String email}) async {
    deletedEmails.add(email);
    return const Success(null);
  }

  @override
  Stream<Authenticated?> get authStateChanges => const Stream.empty();
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
  Future<Result<Set<String>>> readWishlist() async => const Success({'p1'});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async =>
      const Success(null);
}

void main() {
  testWidgets('adapter proxies auth state and clears guest data',
      (tester) async {
    final authRepository = _AuthRepository();
    final auth = AuthCubit(
      authRepository: authRepository,
      profileRepository: StubProfileRepository(),
    );
    final cart = CartCubit(_CartRepository());
    final wishlist = WishlistCubit(_WishlistRepository());
    await wishlist.restore();
    addTearDown(() async {
      await auth.close();
      await cart.close();
      await wishlist.close();
    });

    late BuildContext context;
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider.value(value: cart),
        BlocProvider.value(value: wishlist),
      ],
      child: Builder(builder: (c) {
        context = c;
        return const SizedBox.shrink();
      }),
    ));

    final adapter = SettingsAccountAdapter(context);
    expect(adapter.isAuthenticated, isFalse);

    final result = await adapter.deleteAccount(email: 'user@example.com');
    expect(result, isA<Success<void>>());
    expect(authRepository.deletedEmails, ['user@example.com']);

    adapter.clearGuestData();
    expect(cart.state.items, isEmpty);
    expect(wishlist.state.ids, isEmpty);
  });
}
