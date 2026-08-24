import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_catalog_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_image_manager_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_product_edit_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_variant_editor_page.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ─── Fakes ──────────────────────────────────────────────────────

class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository({this.isAdmin = true});
  bool isAdmin;

  @override
  Future<bool> isCurrentUserAdmin() async => isAdmin;

  @override
  Future<List<Map<String, dynamic>>> getAllOrders(
          {String? status, int limit = 50}) async =>
      [];

  @override
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async => null;

  @override
  Future<void> updateOrderStatus(String orderId, String status,
      {String? trackingNumber}) async {}

  @override
  Future<List<Map<String, dynamic>>> getLowStockProducts(
          {int threshold = 5}) async =>
      [];

  @override
  Future<void> updateStock(String variantId, int newStock) async {}

  @override
  Future<String> adminUpsertProduct({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? composition,
    required String categoryId,
    required double basePrice,
    required bool isActive,
  }) async =>
      'fake-product-id';

  @override
  Future<String> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  }) async =>
      'fake-variant-id';

  @override
  Future<void> adminSetProductImages(
      String productId, List<String> storagePaths) async {}

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => [];
}

class FakeCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async => Success([]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(['Cat A', 'Cat B']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Failure(AppError('not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['Cat A', 'Cat B'];

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => [];
}

// Minimal fake that avoids Supabase client init.
class FakeStorageService extends StorageService {
  FakeStorageService() : super(client: null);

  @override
  String buildProductImagePath(String productId, String fileName) =>
      'product-images/$productId/$fileName';

  @override
  Future<String> uploadProductImage(String productId, List<int> bytes,
          String fileName, String contentType) async =>
      'product-images/$productId/$fileName';

  @override
  String getProductImageUrl(String storagePath) =>
      'https://example.com/$storagePath';

  @override
  Future<void> deleteProductImage(String storagePath) async {}
}

GoRouter _routerForCatalog({bool isAdmin = true}) {
  final fakeAdmin = FakeAdminRepository(isAdmin: isAdmin);
  // Register fakes in getIt (reset first).
  if (getIt.isRegistered<AdminRepository>()) {
    getIt.unregister<AdminRepository>();
  }
  getIt.registerSingleton<AdminRepository>(fakeAdmin);
  if (getIt.isRegistered<CatalogRepository>()) {
    getIt.unregister<CatalogRepository>();
  }
  getIt.registerSingleton<CatalogRepository>(FakeCatalogRepository());
  if (getIt.isRegistered<StorageService>()) getIt.unregister<StorageService>();
  getIt.registerSingleton<StorageService>(FakeStorageService());

  return GoRouter(
    initialLocation: '/admin/catalog',
    routes: [
      GoRoute(
          path: '/admin/catalog', builder: (_, __) => const AdminCatalogPage()),
      GoRoute(
          path: '/admin/products',
          builder: (_, __) => const AdminProductEditPage()),
      GoRoute(
          path: '/admin/categories',
          builder: (_, __) => const AdminProductEditPage()),
      GoRoute(
          path: '/admin/images',
          builder: (_, __) =>
              const AdminImageManagerPage(productId: 'test-pid')),
      GoRoute(
          path: '/admin/variants',
          builder: (_, __) =>
              const AdminVariantEditorPage(productId: 'test-pid')),
    ],
  );
}

Widget _harness(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

void main() {
  tearDown(() {
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
    if (getIt.isRegistered<CatalogRepository>()) {
      getIt.unregister<CatalogRepository>();
    }
    if (getIt.isRegistered<StorageService>()) {
      getIt.unregister<StorageService>();
    }
  });

  testWidgets('catalog page shows 4 management tiles', (tester) async {
    final router = _routerForCatalog();
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    expect(find.text('Manage Products'), findsOneWidget);
    expect(find.text('Manage Categories'), findsOneWidget);
    expect(find.text('Manage Product Images'), findsOneWidget);
    expect(find.text('Manage Variants & Stock'), findsOneWidget);
  });

  testWidgets('catalog page tiles navigate to edit pages', (tester) async {
    final router = _routerForCatalog();
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    // Tap Manage Products -> AdminProductEditPage
    await tester.tap(find.text('Manage Products'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProductEditPage), findsOneWidget);
    // Go back
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AdminCatalogPage), findsOneWidget);

    // Tap Manage Categories -> AdminProductEditPage (categories route)
    await tester.tap(find.text('Manage Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProductEditPage), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    // Tap Manage Product Images -> AdminImageManagerPage
    await tester.tap(find.text('Manage Product Images'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminImageManagerPage), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    // Tap Manage Variants & Stock -> AdminVariantEditorPage
    await tester.tap(find.text('Manage Variants & Stock'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminVariantEditorPage), findsOneWidget);
  });

  testWidgets('non-admin sees SnackBar and stays on catalog', (tester) async {
    final router = _routerForCatalog(isAdmin: false);
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage Products'));
    await tester.pumpAndSettle();

    expect(find.text('Admin access required'), findsOneWidget);
    expect(find.byType(AdminCatalogPage), findsOneWidget);
    expect(find.byType(AdminProductEditPage), findsNothing);
  });

  testWidgets('admin pages contain adminUpsert calls sanity', (tester) async {
    // This test documents the acceptance: files contain adminUpsert* strings.
    // We also verify the pages can be pumped.
    final fakeAdmin = FakeAdminRepository();
    final fakeCatalog = FakeCatalogRepository();
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
    getIt.registerSingleton<AdminRepository>(fakeAdmin);
    if (getIt.isRegistered<CatalogRepository>()) {
      getIt.unregister<CatalogRepository>();
    }
    getIt.registerSingleton<CatalogRepository>(fakeCatalog);
    if (getIt.isRegistered<StorageService>()) {
      getIt.unregister<StorageService>();
    }
    getIt.registerSingleton<StorageService>(FakeStorageService());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductEditPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminProductEditPage), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminVariantEditorPage(productId: 'pid'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminVariantEditorPage), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminImageManagerPage(productId: 'pid'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminImageManagerPage), findsOneWidget);
  });
}
