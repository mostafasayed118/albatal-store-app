import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/addresses/data/local_address_repository.dart';
import '../../features/addresses/domain/repositories/address_repository.dart';
import '../../features/admin/data/supabase_admin_repository.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/data/supabase_profile_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/profile_repository.dart';
import '../../features/payments/data/paymob_payment_service.dart';
import '../../features/payments/domain/repositories/payment_service.dart';
import '../../features/settings/data/local_settings_repository.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/storefront/data/checkout_service.dart';
import '../../features/storefront/data/local_cart_repository.dart';
import '../../features/storefront/data/local_catalog_repository.dart';
import '../../features/storefront/data/local_orders_repository.dart';
import '../../features/storefront/data/local_wishlist_repository.dart';
import '../../features/storefront/data/storefront_persistence.dart';
import '../../features/storefront/domain/repositories/cart_repository.dart';
import '../../features/storefront/domain/repositories/catalog_repository.dart';
import '../../features/storefront/domain/repositories/checkout_repository.dart';
import '../../features/storefront/domain/repositories/orders_repository.dart';
import '../../features/storefront/domain/repositories/wishlist_repository.dart';
import '../../features/support/data/local_support_repository.dart';
import '../../features/support/domain/repositories/support_repository.dart';

final getIt = GetIt.instance;

/// Configure the dependency-injection container.
///
/// All repositories and services are registered as lazy singletons so
/// they're created once on first access and shared thereafter. Cubits
/// are NOT registered here — they're created per-route via
/// [BlocProvider] in the widget tree (per INSTRUCTIONS.md §B.3 and
/// the GetIt convention of keeping stateful objects out of the DI
/// container unless they're truly app-scoped).
Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();
  getIt
    ..registerSingleton<SharedPreferences>(preferences)
    ..registerLazySingleton<SettingsRepository>(
        () => LocalSettingsRepository(getIt<SharedPreferences>()))
    ..registerLazySingleton<AddressRepository>(
        () => LocalAddressRepository(getIt<SharedPreferences>()))
    ..registerLazySingleton<AdminRepository>(() => SupabaseAdminRepository())
    ..registerLazySingleton<AuthRepository>(() => SupabaseAuthRepository())
    ..registerLazySingleton<ProfileRepository>(() => SupabaseProfileRepository())
    ..registerLazySingleton<PaymentService>(() => PaymobPaymentService())
    ..registerLazySingleton<CheckoutRepository>(() => CheckoutService())
    ..registerLazySingleton<SupportRepository>(() => LocalSupportRepository())
    ..registerLazySingleton<LocalStorefrontPersistence>(
        () => LocalStorefrontPersistence(getIt<SharedPreferences>()))
    ..registerLazySingleton<CartRepository>(
        () => LocalCartRepository(getIt<LocalStorefrontPersistence>()))
    ..registerLazySingleton<WishlistRepository>(
        () => LocalWishlistRepository(getIt<LocalStorefrontPersistence>()))
    ..registerLazySingleton<OrdersRepository>(
        () => LocalOrdersRepository(getIt<LocalStorefrontPersistence>()))
    ..registerLazySingleton<CatalogRepository>(LocalCatalogRepository.new);
}
