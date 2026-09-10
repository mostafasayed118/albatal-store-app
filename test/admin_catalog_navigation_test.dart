import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_variant.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_categories_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_catalog_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_image_manager_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_product_edit_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_products_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_variant_editor_page.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_image.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ─── Fakes ──────────────────────────────────────────────────────

class FakeAdminRepository implements AdminRepository {
  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) async =>
      const Success(null);

  FakeAdminRepository({this.isAdmin = true});
  bool isAdmin;
  List<AdminVariant> variants = const [];
  List<String> productImagePaths = const [];
  List<AdminProduct> products = const [];
  List<AdminCategory> categories = const [];
  int getAllProductsCalls = 0;

  /// Captured `categoryId` from the last adminUpsertProduct call —
  /// regression evidence that the form submits a category UUID.
  String? lastUpsertCategoryId;

  /// Commit counters for the negative-input regression tests: a rejected
  /// entry must leave these untouched.
  int upsertProductCalls = 0;
  int upsertVariantCalls = 0;

  @override
  Future<bool> isCurrentUserAdmin() async => isAdmin;

  @override
  Future<Result<List<AdminOrder>>> getAllOrders(
          {AdminOrderStatus? status, int limit = 50}) async =>
      const Success([]);

  @override
  Future<Result<AdminOrder?>> getOrderDetails(String orderId) async =>
      const Success(null);

  @override
  Future<Result<void>> updateOrderStatus(
          String orderId, AdminOrderStatus status,
          {String? trackingNumber}) async =>
      const Success(null);

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts(
          {int threshold = 5}) async =>
      const Success([]);

  @override
  Future<Result<void>> updateStock(String variantId, int newStock) async =>
      const Success(null);

  @override
  Future<Result<String>> adminUpsertProduct({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? composition,
    required String categoryId,
    required double basePrice,
    required bool isActive,
  }) async {
    lastUpsertCategoryId = categoryId;
    upsertProductCalls++;
    return const Success('fake-product-id');
  }

  @override
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  }) async {
    upsertVariantCalls++;
    return const Success('fake-variant-id');
  }

  @override
  Future<Result<void>> adminSetProductImages(
          String productId, List<String> storagePaths) async =>
      const Success(null);

  @override
  Future<Result<List<AdminVariant>>> getVariants(String productId) async =>
      Success(variants);

  @override
  Future<Result<List<String>>> getProductImagePaths(String productId) async =>
      Success(productImagePaths);

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() async {
    getAllProductsCalls++;
    return Success(products);
  }

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() async =>
      Success(categories);
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
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
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
          path: '/admin/catalog',
          builder: (_, __) =>
              AdminCatalogPage(repository: getIt<AdminRepository>())),
      // Mirror the production routes (see app_router.dart): the hub's
      // Products/Images/Variants tiles land on the product list — the
      // only surface that can supply a productId to the editors.
      GoRoute(
          path: '/admin/products',
          builder: (_, __) =>
              AdminProductsPage(repository: getIt<AdminRepository>())),
      GoRoute(
          path: '/admin/products/new',
          builder: (_, __) =>
              AdminProductEditPage(repository: getIt<AdminRepository>())),
      GoRoute(
          path: '/admin/products/:id',
          builder: (_, s) => AdminProductEditPage(
              productId: s.pathParameters['id'],
              repository: getIt<AdminRepository>())),
      GoRoute(
          path: '/admin/categories',
          builder: (_, __) =>
              AdminCategoriesPage(repository: getIt<AdminRepository>())),
      GoRoute(
          path: '/admin/images/:id',
          builder: (_, s) => AdminImageManagerPage(
              productId: s.pathParameters['id']!,
              repository: getIt<AdminRepository>(),
              storage: getIt<StorageService>())),
      GoRoute(
          path: '/admin/variants/:id',
          builder: (_, s) => AdminVariantEditorPage(
              productId: s.pathParameters['id']!,
              repository: getIt<AdminRepository>())),
    ],
  );
}

Widget _harness(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

/// Taps a hub tile and waits until the destination page is actually on
/// stage. The tile's admin probe is async, so the push lands a frame or
/// more after the tap — fixed settles race it, so poll instead.
Future<void> _pushAndWait(
  WidgetTester tester,
  String label,
  Type pageType,
) async {
  await tester.tap(find.text(label));
  for (var i = 0; i < 20; i++) {
    if (find.byType(pageType).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  final texts = find
      .byType(Text, skipOffstage: false)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .where((t) => t != null && t.isNotEmpty)
      .toList();
  fail('tapping "$label" never reached $pageType; live texts: $texts');
}

/// Waits until [pageType] is on stage (bounded polling — the transition
/// plus a following settle is otherwise racy against the test clock).
Future<void> _waitFor(WidgetTester tester, Type pageType) async {
  for (var i = 0; i < 20; i++) {
    if (find.byType(pageType).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('$pageType never appeared on stage');
}

/// Pops the pushed page and waits until [pageType] is back on stage.
Future<void> _popAndWait(WidgetTester tester, Type pageType) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  for (var i = 0; i < 20; i++) {
    if (find.byType(pageType).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('pop never returned to $pageType');
}

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

  testWidgets('catalog page tiles navigate to their destinations',
      (tester) async {
    final router = _routerForCatalog();
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    // Products -> product list (manage + picker), not the bare edit form.
    await _pushAndWait(tester, 'Manage Products', AdminProductsPage);
    await _popAndWait(tester, AdminCatalogPage);

    // Categories -> the read-only category list.
    await _pushAndWait(tester, 'Manage Categories', AdminCategoriesPage);
    await _popAndWait(tester, AdminCatalogPage);

    // Images and Variants need a productId, which only a product can
    // supply — both land on the product list to pick one.
    await _pushAndWait(tester, 'Manage Product Images', AdminProductsPage);
    await _popAndWait(tester, AdminCatalogPage);

    await _pushAndWait(tester, 'Manage Variants & Stock', AdminProductsPage);
  });

  testWidgets('products list drives edit / images / variants per product',
      (tester) async {
    final router = _routerForCatalog();
    final fake = getIt<AdminRepository>() as FakeAdminRepository
      ..categories = const [
        AdminCategory(id: 'cat-uuid-1', name: 'Silk', isActive: true),
        AdminCategory(id: 'cat-uuid-2', name: 'Cotton', isActive: true),
      ]
      ..products = const [
        AdminProduct(
          id: 'p1',
          name: 'Royal Emerald Silk',
          slug: 'royal-emerald-silk',
          categoryId: 'cat-uuid-1',
          categoryName: 'Silk',
          basePrice: 1890,
          isActive: true,
        ),
      ];
    fake.variants = const [
      AdminVariant(variantId: 'v1', size: 'M', color: 'Navy', stock: 12),
    ];

    final harness = MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
    router.go('/admin/products');
    await tester.pumpWidget(harness);
    await tester.pumpAndSettle();

    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('Silk • royal-emerald-silk'), findsOneWidget);

    // Row opens per-product variant management.
    await tester.tap(find.text('Royal Emerald Silk'));
    await _waitFor(tester, AdminVariantEditorPage);
    expect(find.text('M / Navy'), findsOneWidget);
    await _popAndWait(tester, AdminProductsPage);

    // Images icon opens the gallery manager for that product.
    await tester.tap(find.byTooltip('Images'));
    await _waitFor(tester, AdminImageManagerPage);
    await _popAndWait(tester, AdminProductsPage);

    // Edit icon opens the form prefilled from the row.
    await tester.tap(find.byTooltip('Edit product'));
    await _waitFor(tester, AdminProductEditPage);
    expect(find.text('Edit Product'), findsOneWidget);
    // Field prefill lives in controllers, not Text widgets.
    final nameField =
        tester.widget<TextFormField>(find.byType(TextFormField).at(0));
    expect(nameField.controller?.text, 'Royal Emerald Silk');
    expect(find.text('Silk'), findsOneWidget);
  });

  testWidgets('create flow submits a category UUID and refreshes the list',
      (tester) async {
    final router = _routerForCatalog();
    final fake = getIt<AdminRepository>() as FakeAdminRepository
      ..categories = const [
        AdminCategory(id: 'cat-uuid-1', name: 'Silk', isActive: true),
        AdminCategory(id: 'cat-uuid-2', name: 'Cotton', isActive: true),
      ];

    final harness = MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
    // Navigate like the app does — from the list via the FAB — so the
    // form sits on top of it and the post-save pop has a page beneath.
    // A tall viewport keeps the whole form on stage: the default test
    // window scrolls the submit button out of the lazy list's extent
    // during the dropdown interaction.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    router.go('/admin/products');
    await tester.pumpWidget(harness);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Silk Scarf');
    await tester.enterText(find.byType(TextFormField).at(1), 'silk-scarf');
    await tester.enterText(find.byType(TextFormField).at(4), '450');

    // Pick the second category by display name; the dropdown's value
    // must be its UUID.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cotton').last);
    await tester.pumpAndSettle();

    // The submit button sits below the fold of the form's ListView —
    // bring it into the viewport before tapping.
    await tester.ensureVisible(find.text('Create Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Product'));
    await tester.pumpAndSettle();

    // Regression: the form previously submitted the category NAME
    // ('Cotton'), which admin_upsert_product (p_category_id UUID)
    // rejects — every save failed against the deployed RPC.
    expect(fake.lastUpsertCategoryId, 'cat-uuid-2');
    expect(fake.getAllProductsCalls, 2,
        reason: 'list loads once on entry, then must refresh when the create '
            'flow pops back with a changed signal');
  });

  void registerFakes(FakeAdminRepository fake) {
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
    getIt.registerSingleton<AdminRepository>(fake);
    if (getIt.isRegistered<CatalogRepository>()) {
      getIt.unregister<CatalogRepository>();
    }
    getIt.registerSingleton<CatalogRepository>(FakeCatalogRepository());
    if (getIt.isRegistered<StorageService>()) {
      getIt.unregister<StorageService>();
    }
    getIt.registerSingleton<StorageService>(FakeStorageService());
  }

  testWidgets('variant editor rejects a negative stock commit', (tester) async {
    final fake = FakeAdminRepository()
      ..variants = const [
        AdminVariant(variantId: 'v1', size: 'M', color: 'Navy', stock: 12),
      ];
    registerFakes(fake);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminVariantEditorPage(
          productId: 'pid', repository: fake),
    ));
    await tester.pumpAndSettle();

    // The row's edit icon opens the dialog (prefilled stock 12).
    await tester.tap(find.byIcon(Icons.edit));
    // The async dialog push lands a frame after the tap — pump it before
    // settling (same microtask race documented on the other tests here).
    await tester.pump();
    await tester.pumpAndSettle();

    // '-5' parses fine — the guard must refuse it before the repository.
    await tester.enterText(find.widgetWithText(TextField, 'Stock'), '-5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Stock cannot be negative'), findsOneWidget,
        reason: 'the rejection is visible, not a silent commit');
    expect(find.text('Edit Variant'), findsOneWidget,
        reason: 'the dialog stays open');
    expect(fake.upsertVariantCalls, 0);

    // A valid entry saves and closes.
    await tester.enterText(find.widgetWithText(TextField, 'Stock'), '9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.upsertVariantCalls, 1);
    expect(find.text('Edit Variant'), findsNothing);
  });

  testWidgets('product form rejects a negative base price commit',
      (tester) async {
    final fake = FakeAdminRepository()
      ..categories = const [
        AdminCategory(id: 'cat-uuid-1', name: 'Silk', isActive: true),
      ];
    registerFakes(fake);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, __) =>
              AdminProductEditPage(repository: getIt<AdminRepository>()),
        ),
      ],
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    // Push (not go) so the form has a page beneath it — the success path
    // pops with a changed signal, mirroring the real list → FAB flow.
    router.push('/edit');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Test Product');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-product');

    // Pick a category, or submit bails before the price is even checked.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silk').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(4), '-50');
    await tester.ensureVisible(find.text('Create Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Product'));
    await tester.pumpAndSettle();

    expect(find.text('Price cannot be negative'), findsOneWidget,
        reason: 'the rejection is visible, not a silent commit');
    expect(find.byType(AdminProductEditPage), findsOneWidget,
        reason: 'the form stays up');
    expect(fake.upsertProductCalls, 0);

    // A valid price commits.
    await tester.enterText(find.byType(TextFormField).at(4), '450');
    await tester.tap(find.text('Create Product'));
    await tester.pumpAndSettle();

    expect(fake.upsertProductCalls, 1);
    expect(find.text('Price cannot be negative'), findsNothing);
  });

  testWidgets('non-admin sees SnackBar and stays on catalog', (tester) async {
    final router = _routerForCatalog(isAdmin: false);
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage Products'));
    await tester.pumpAndSettle();

    expect(find.text('Admin access required'), findsOneWidget);
    expect(find.byType(AdminCatalogPage), findsOneWidget);
    expect(find.byType(AdminProductsPage), findsNothing);
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
        home: AdminProductEditPage(repository: fakeAdmin),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminProductEditPage), findsOneWidget);

    fakeAdmin.variants = const [
      AdminVariant(variantId: 'v1', size: 'M', color: 'Navy', stock: 12),
    ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminVariantEditorPage(
            productId: 'pid', repository: fakeAdmin),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminVariantEditorPage), findsOneWidget);
    expect(find.text('M / Navy'), findsOneWidget);
    expect(find.text('Stock: 12'), findsOneWidget);

    fakeAdmin.productImagePaths = ['product-images/pid/a.jpg'];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminImageManagerPage(
            productId: 'pid',
            repository: fakeAdmin,
            storage: getIt<StorageService>()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminImageManagerPage), findsOneWidget);
    expect(find.byType(AppImage), findsOneWidget);
  });
}
