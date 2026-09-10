import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_variant.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_categories_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_products_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// State coverage for the two new catalog-hub destinations (routes
/// /admin/products and /admin/categories). The hub's Images and Variants
/// tiles land on the product list, so its loading/error/empty/data states
/// are the entry experience for four of the hub's tiles.

class _FakeAdminRepository implements AdminRepository {
  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) async =>
      const Success(null);

  _FakeAdminRepository();

  List<AdminProduct> products = const [];
  List<AdminCategory> categories = const [];
  bool failProducts = false;
  bool failCategories = false;

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() async => failProducts
      ? const Failure(AppError('Failed to load products'))
      : Success(products);

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() async => failCategories
      ? const Failure(AppError('Failed to load categories'))
      : Success(categories);

  @override
  Future<bool> isCurrentUserAdmin() async => true;

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
  }) async =>
      const Success('new-id');

  @override
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  }) async =>
      const Success('new-id');

  @override
  Future<Result<void>> adminSetProductImages(
          String productId, List<String> storagePaths) async =>
      const Success(null);

  @override
  Future<Result<List<AdminVariant>>> getVariants(String productId) async =>
      const Success([]);

  @override
  Future<Result<List<String>>> getProductImagePaths(String productId) async =>
      const Success([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdminRepository repo;

  setUp(() {
    repo = _FakeAdminRepository();
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
    getIt.registerSingleton<AdminRepository>(repo);
  });

  tearDown(() {
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
  });

  Widget harness(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );

  group('AdminProductsPage', () {
    testWidgets('shows a loading state, then the product rows', (tester) async {
      repo.products = const [
        AdminProduct(
          id: 'p-1',
          name: 'Royal Emerald Silk',
          slug: 'royal-emerald-silk',
          categoryId: 'c-1',
          categoryName: 'Silk',
          basePrice: 1890,
          isActive: true,
        ),
        AdminProduct(
          id: 'p-2',
          name: 'Egyptian Cotton',
          slug: 'egyptian-cotton',
          categoryId: 'c-2',
          categoryName: 'Cotton',
          basePrice: 990,
          isActive: false,
        ),
      ];

      // A phone-viewport-sized window would push the second row offstage
      // (lazy list); a tall surface keeps both rows built for the asserts.
      tester.view.physicalSize = const Size(1080, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(AdminProductsPage(repository: repo)));
      // First pump shows the loading spinner; the repository future then
      // resolves into the list.
      await tester.pumpAndSettle();

      expect(find.text('Royal Emerald Silk'), findsOneWidget);
      expect(find.text('Silk • royal-emerald-silk'), findsOneWidget);
      expect(find.text('Egyptian Cotton'), findsOneWidget);
      // Inactive products are the manage list's reason to exist: the
      // row says so in words, not just a dimmed icon.
      expect(find.text('Cotton • egyptian-cotton • Inactive'), findsOneWidget);
    });

    testWidgets('failed load renders the error state with retry',
        (tester) async {
      repo.failProducts = true;

      await tester.pumpWidget(harness(AdminProductsPage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load products'), findsOneWidget);

      repo.failProducts = false;
      repo.products = const [
        AdminProduct(
          id: 'p-1',
          name: 'Royal Emerald Silk',
          slug: 'royal-emerald-silk',
          categoryId: 'c-1',
          categoryName: 'Silk',
          basePrice: 1890,
          isActive: true,
        ),
      ];
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Royal Emerald Silk'), findsOneWidget);
    });

    testWidgets('empty catalog renders an inviting create state',
        (tester) async {
      await tester.pumpWidget(harness(AdminProductsPage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('No products yet'), findsOneWidget);
      expect(find.text('New Product'), findsWidgets);
    });
  });

  group('AdminCategoriesPage', () {
    testWidgets('lists categories with active flags', (tester) async {
      repo.categories = const [
        AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
        AdminCategory(id: 'c-2', name: 'Wool', isActive: false),
      ];

      await tester.pumpWidget(harness(AdminCategoriesPage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Silk'), findsOneWidget);
      expect(find.text('Wool'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('failed load offers retry that recovers', (tester) async {
      repo.failCategories = true;

      await tester.pumpWidget(harness(AdminCategoriesPage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load categories'), findsOneWidget);

      repo.failCategories = false;
      repo.categories = const [
        AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
      ];
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Silk'), findsOneWidget);
    });

    testWidgets('empty category table renders an explanatory empty state',
        (tester) async {
      await tester.pumpWidget(harness(AdminCategoriesPage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('No categories yet'), findsOneWidget);
    });
  });
}
