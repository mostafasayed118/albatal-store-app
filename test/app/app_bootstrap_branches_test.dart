import 'dart:async';

import 'package:al_batal_elite/app.dart';
import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
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
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/shared/services/connectivity_gate.dart';
import 'package:al_batal_elite/shared/services/deep_link_service.dart';
import 'package:al_batal_elite/shared/services/push_service.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:al_batal_elite/shared/services/whatsapp_share_service.dart';
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
  final controller = StreamController<Authenticated?>.broadcast();

  @override
  Stream<Authenticated?> get authStateChanges => controller.stream;

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
      Success(Profile(id: userId, isAdmin: false));

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
  final controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> incoming() => controller.stream;
}

final class _Push implements PushService {
  final logins = <String>[];
  int logouts = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> login(String userId) async => logins.add(userId);

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<void> requestPermission() async {}

  @override
  String? get subscriptionId => null;

  @override
  Future<void> addSubscriptionObserver(
      void Function(String? id) listener) async {}

  @override
  void removeSubscriptionObserver(void Function(String? id) listener) {}
}

void main() {
  testWidgets('app wires DI, deep links and push identity transitions',
      (tester) async {
    final persistence = MemoryStorefrontPersistence();
    final catalog = _Catalog();
    final authRepo = _Auth();
    final deepLinks = _DeepLinks();
    final push = _Push();

    getIt
      ..registerSingleton<CartRepository>(persistence)
      ..registerSingleton<CatalogRepository>(catalog)
      ..registerSingleton<WholesalePriceSource>(_Wholesale())
      ..registerSingleton<AuthRepository>(authRepo)
      ..registerSingleton<ProfileRepository>(_Profile())
      ..registerSingleton<AddressRepository>(_Addresses())
      ..registerSingleton<OrderSnapshotPort>(_Snapshots())
      ..registerSingleton<WishlistRepository>(persistence)
      ..registerSingleton<OrdersRepository>(persistence)
      ..registerSingleton<RecentSearchesStore>(_Searches())
      ..registerSingleton<RecentlyViewedStore>(MemoryRecentlyViewedStore())
      ..registerSingleton<OnboardingRepository>(_Onboarding())
      ..registerSingleton<SettingsRepository>(_Settings())
      ..registerSingleton<DeepLinkService>(deepLinks)
      ..registerSingleton<PushService>(push)
      ..registerSingleton<WhatsAppShareService>(_WhatsApp())
      ..registerSingleton<ShareService>(_Share())
      ..registerSingleton<ConnectivityGate>(ConnectivityGate())
      ..registerSingleton<AdminRepository>(_AdminFake());

    await tester.pumpWidget(const AlBatalApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);

    // Force the lazily-created app-scoped providers to build as well.
    final appContext = tester.element(find.byType(MaterialApp));
    expect(BlocProvider.of<OrdersCubit>(appContext), isNotNull);

    deepLinks.controller
        .add(Uri.parse('https://albatal.app/product/fabric-42'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    deepLinks.controller.add(Uri.parse('https://albatal.app/catalog?q=silk'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    authRepo.controller.add(const Authenticated('user-1'));
    await tester.pump();
    await tester.pump();
    expect(push.logins, ['user-1']);

    authRepo.controller.add(null);
    await tester.pump();
    await tester.pump();
    expect(push.logouts, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await deepLinks.controller.close();
    await authRepo.controller.close();
    await getIt.reset();
  });
}

final class _AdminFake extends Fake implements AdminRepository {}

final class _WhatsApp extends Fake implements WhatsAppShareService {}

final class _Share extends Fake implements ShareService {}
