import 'package:al_batal_elite/app.dart';
import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/order_snapshot_port.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recent_searches_store.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recently_viewed_store.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wholesale_price_source.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/shared/services/connectivity_gate.dart';
import 'package:al_batal_elite/shared/services/deep_link_service.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:al_batal_elite/shared/smoke/smoke_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/memory_storefront_persistence.dart';
import '../helpers/recently_viewed_store_stub.dart';

final class _Catalog extends Fake implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([]);

  @override
  Future<Result<List<String>>> fetchCategories() async => const Success([]);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const [];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success([]);
}

final class _Auth implements AuthRepository {
  @override
  Stream<Authenticated?> get authStateChanges => const Stream.empty();

  @override
  Future<Result<Authenticated?>> checkSession() async =>
      const Success(Authenticated('user-1'));

  @override
  Future<Result<AuthOutcome>> signUp(
          {required String email,
          required String password,
          String? fullName}) async =>
      const Success(ConfirmationRequired());

  @override
  Future<Result<Authenticated>> signIn(
          {required String email, required String password}) async =>
      const Success(Authenticated('user-1'));

  @override
  Future<Result<void>> resetPassword(String email) async => const Success(null);

  @override
  Future<Result<void>> updatePassword(String newPassword) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);
}

final class _Profile implements ProfileRepository {
  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      Success(Profile(id: userId, isAdmin: true));

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

final class _Addresses implements AddressRepository {
  @override
  Future<Result<List<Address>>> read() async => const Success([]);

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

final class _Snapshots implements OrderSnapshotPort {
  @override
  Future<void> clearOrderSnapshots() async {}
}

final class _Wholesale implements WholesalePriceSource {
  @override
  Future<Map<String, Money>> fetchWholesalePrices(
          Iterable<String> productIds) async =>
      {};
}

final class _Searches implements RecentSearchesStore {
  @override
  List<String> load() => const [];

  @override
  void record(String query) {}

  @override
  void clear() {}
}

final class _Onboarding implements OnboardingRepository {
  @override
  Future<Result<bool>> hasCompleted() async => const Success(true);

  @override
  Future<Result<void>> complete() async => const Success(null);
}

final class _Settings implements SettingsRepository {
  @override
  Future<Result<AppSettings>> read() async => const Success(
      AppSettings(themeMode: AppThemeMode.system, locale: AppLocale.english));

  @override
  Future<Result<void>> saveThemeMode(AppThemeMode themeMode) async =>
      const Success(null);

  @override
  Future<Result<void>> saveLocale(AppLocale locale) async =>
      const Success(null);
}

final class _DeepLinks implements DeepLinkService {
  @override
  Stream<Uri> incoming() => const Stream<Uri>.empty();
}

final class _Share implements ShareService {
  @override
  Future<void> shareText(String message) async {}

  @override
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {}
}

final class _Admin extends Fake implements AdminRepository {
  @override
  Future<bool> isCurrentUserAdmin() async => true;

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() async =>
      const Success([]);

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() async =>
      const Success([]);

  @override
  Future<Result<List<AdminOrder>>> getAllOrders(
          {AdminOrderStatus? status, int limit = 50}) async =>
      const Success([]);

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts(
          {int threshold = 5}) async =>
      const Success([
        LowStockVariant(
          variantId: 'v1',
          productName: 'Silk',
          size: 'M',
          color: 'Emerald',
          stock: 2,
        ),
      ]);
}

void main() {
  testWidgets(
      'a non-null exit hook mounts the smoke harness and builds the '
      'lazy addresses provider', (tester) async {
    final persistence = MemoryStorefrontPersistence();

    getIt
      ..registerSingleton<CartRepository>(persistence)
      ..registerSingleton<CatalogRepository>(_Catalog())
      ..registerSingleton<WholesalePriceSource>(_Wholesale())
      ..registerSingleton<AuthRepository>(_Auth())
      ..registerSingleton<ProfileRepository>(_Profile())
      ..registerSingleton<AddressRepository>(_Addresses())
      ..registerSingleton<OrderSnapshotPort>(_Snapshots())
      ..registerSingleton<WishlistRepository>(persistence)
      ..registerSingleton<OrdersRepository>(persistence)
      ..registerSingleton<RecentSearchesStore>(_Searches())
      ..registerSingleton<RecentlyViewedStore>(MemoryRecentlyViewedStore())
      ..registerSingleton<OnboardingRepository>(_Onboarding())
      ..registerSingleton<SettingsRepository>(_Settings())
      ..registerSingleton<DeepLinkService>(_DeepLinks())
      ..registerSingleton<ConnectivityGate>(ConnectivityGate())
      ..registerSingleton<ShareService>(_Share())
      ..registerSingleton<AdminRepository>(_Admin());

    addTearDown(() async {
      await getIt.reset();
    });

    var exitCode = -1;
    await tester.pumpWidget(AlBatalApp(exitApp: (code) => exitCode = code));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SmokeHarness), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);

    // The addresses provider is lazy: force its factory closure (app.dart).
    final appContext = tester.element(find.byType(MaterialApp));
    expect(BlocProvider.of<AddressesCubit>(appContext), isNotNull);

    // Advance the fake clock until the harness's exit hook fires; bounded so
    // a hung scenario still fails the expect below instead of looping.
    for (var i = 0; i < 60 && exitCode == -1; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(exitCode, 0, reason: 'every smoke scenario must pass');
  });
}
