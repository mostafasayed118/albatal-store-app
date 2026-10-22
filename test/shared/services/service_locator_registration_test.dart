import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_wholesale_prices_port.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/coupons_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/idempotency_store.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/usecases/place_checkout_order_usecase.dart';
import 'package:al_batal_elite/features/support/domain/repositories/support_repository.dart';
import 'package:al_batal_elite/shared/services/analytics_service.dart';
import 'package:al_batal_elite/shared/services/crash_reporting_service.dart';
import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:al_batal_elite/shared/services/oauth_service.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:al_batal_elite/shared/services/whatsapp_share_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves the lazy registrations whose factory closures are otherwise never
/// executed by existing tests. Supabase is initialized with dummy public
/// credentials; nothing here performs network I/O.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await getIt.reset();
    await Supabase.instance.dispose();
  });

  test('configureDependencies resolves every lazy service factory', () async {
    await configureDependencies();

    expect(getIt<AddressRepository>(), isNotNull);
    expect(getIt<AdminRepository>(), isNotNull);
    expect(getIt<AdminWholesalePricesPort>(), isNotNull);
    expect(getIt<PaymentService>(), isNotNull);
    expect(getIt<CheckoutRepository>(), isNotNull);
    expect(getIt<SupportRepository>(), isNotNull);
    expect(getIt<IdempotencyStore>(), isNotNull);
    expect(getIt<PlaceCheckoutOrderUseCase>(), isNotNull);
    expect(getIt<OrdersRepository>(), isNotNull);
    expect(getIt<StorageService>(), isNotNull);
    expect(getIt<ImageCompressor>(), isNotNull);
    expect(getIt<ExternalLinkLauncher>(), isNotNull);
    expect(getIt<WhatsAppShareService>(), isNotNull);
    expect(getIt<CouponsRepository>(), isNotNull);
    expect(getIt<ReviewsRepository>(), isNotNull);
    expect(getIt<AnalyticsService>(), isNotNull);
    expect(getIt<NotificationService>(), isNotNull);
    expect(getIt<OAuthService>(), isNotNull);
    expect(getIt<CrashReportingService>(), isA<NoOpCrashReportingService>());
  });
}
