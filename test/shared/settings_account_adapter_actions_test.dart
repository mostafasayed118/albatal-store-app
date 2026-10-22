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

/// Auth double whose account deletion fails, so the adapter's failure
/// pass-through (not just its success path) is exercised.
final class _FailingDeleteAuthRepository implements AuthRepository {
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
    return const Failure(AppError('deletion refused'));
  }

  @override
  Stream<Authenticated?> get authStateChanges =>
      const Stream<Authenticated?>.empty();
}

/// Cart double that records every persisted cart.
final class _RecordingCartRepository implements CartRepository {
  final writes = <List<CartItem>>[];

  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      const Success([]);

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async {
    writes.add(List<CartItem>.of(items));
    return const Success(null);
  }
}

/// Wishlist double that records every persisted id set.
final class _RecordingWishlistRepository implements WishlistRepository {
  final writes = <Set<String>>[];

  @override
  Future<Result<Set<String>>> readWishlist() async => const Success({'p1'});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async {
    writes.add(Set<String>.of(ids));
    return const Success(null);
  }
}

void main() {
  testWidgets('the adapter forwards a refused account deletion',
      (tester) async {
    final authRepository = _FailingDeleteAuthRepository();
    final auth = AuthCubit(
      authRepository: authRepository,
      profileRepository: StubProfileRepository(),
    );
    final cart = CartCubit(_RecordingCartRepository());
    final wishlist = WishlistCubit(_RecordingWishlistRepository());
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
    final result = await adapter.deleteAccount(email: 'user@example.com');

    expect(result, isA<Failure<void>>());
    expect(authRepository.deletedEmails, ['user@example.com']);
  });

  testWidgets('clearing guest data wipes the persisted cart and wishlist',
      (tester) async {
    final cartRepository = _RecordingCartRepository();
    final wishlistRepository = _RecordingWishlistRepository();
    final auth = AuthCubit(
      authRepository: StubAuthRepository(),
      profileRepository: StubProfileRepository(),
    );
    final cart = CartCubit(cartRepository);
    final wishlist = WishlistCubit(wishlistRepository);
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
    adapter.clearGuestData();
    await tester.pumpAndSettle();

    expect(cartRepository.writes.last, isEmpty);
    expect(wishlistRepository.writes.last, isEmpty);
    expect(cart.state.items, isEmpty);
    expect(wishlist.state.ids, isEmpty);
  });
}
