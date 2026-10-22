// ignore_for_file: prefer_const_constructors
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_coupon.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_sales.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_variant.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_wholesale_price_entry.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';

/// Configurable, whole-facade admin repository for the coverage tests.
///
/// The older fakes in `admin_catalog_navigation_test.dart` are scoped to
/// navigation and cannot be imported from another library (they are public
/// but the file is a test, not a helper). This copy exists so the new
/// branch tests can drive one repository surface at a time without
/// re-implementing the ~20-method facade in every file.
class TestOnlyAdminRepository implements AdminRepository {
  bool isAdmin = true;

  /// When set, [isCurrentUserAdmin] throws it (AppError vs generic error
  /// drives the two catch branches on the catalog hub).
  Object? adminCheckError;

  Result<List<AdminProduct>> productsResult = const Success(<AdminProduct>[]);
  Result<AdminProduct?> productByIdResult = const Success(null);
  Result<List<AdminCategory>> categoriesResult =
      const Success(<AdminCategory>[]);

  /// When set, [getAllCategories] throws it (the loader's catch branch).
  Object? categoriesError;

  /// Full control over the category read (product-edit tests hold the
  /// loading state open to exercise the submit guard).
  Future<Result<List<AdminCategory>>> Function()? categoriesHandler;

  Result<List<AdminVariant>> variantsResult = const Success(<AdminVariant>[]);
  Result<List<String>> imagePathsResult = const Success(<String>[]);
  Result<String> upsertProductResult = const Success('product-id');
  Result<String> upsertVariantResult = const Success('variant-id');
  Result<void> setImagesResult = const Success(null);
  Result<void> updateStockResult = const Success(null);
  Result<List<AdminOrder>> ordersResult = const Success(<AdminOrder>[]);
  Result<AdminOrder?> orderDetailsResult = const Success(null);
  Result<void> orderStatusResult = const Success(null);
  Result<void> tierResult = const Success(null);
  Result<List<({String id, String product, String text, int rating})>>
      pendingReviewsResult = const Success(
    <({String id, String product, String text, int rating})>[],
  );
  Result<void> reviewStatusResult = const Success(null);

  Object? setImagesError;

  /// Full control over the image-save call (queued mutation tests need a
  /// future completed after the page has been unmounted).
  Future<Result<void>> Function(String productId, List<String> paths)?
      setImagesHandler;

  /// Full control over the variant save call.
  Future<Result<String>> Function({
    required String productId,
    required String size,
    required String color,
    required int stock,
    Money? priceOverride,
  })? upsertVariantHandler;

  int adminChecks = 0;
  int upsertProductCalls = 0;
  int upsertVariantCalls = 0;
  int imagePathReads = 0;
  String? lastUpsertProductId;
  String? lastUpsertCategoryId;
  Money? lastUpsertBasePrice;
  String? lastUpsertSize;
  String? lastUpsertColor;
  int? lastUpsertStock;
  Money? lastUpsertPriceOverride;
  List<String>? lastSavedImages;

  @override
  Future<bool> isCurrentUserAdmin() async {
    adminChecks++;
    final failure = adminCheckError;
    if (failure != null) throw failure;
    return isAdmin;
  }

  @override
  Future<Result<AdminProduct?>> getProductById(String productId) async =>
      productByIdResult;

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() async => productsResult;

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() async {
    final handler = categoriesHandler;
    if (handler != null) return handler();
    final failure = categoriesError;
    if (failure != null) throw failure;
    return categoriesResult;
  }

  @override
  Future<Result<void>> updateStock(String variantId, int newStock) async =>
      updateStockResult;

  @override
  Future<Result<String>> adminUpsertProduct({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? composition,
    String? care,
    String? origin,
    int? widthCm,
    int? gsm,
    bool? sellByLength,
    double? minCutMeters,
    required String categoryId,
    required Money basePrice,
    required bool isActive,
  }) async {
    upsertProductCalls++;
    lastUpsertProductId = id;
    lastUpsertCategoryId = categoryId;
    lastUpsertBasePrice = basePrice;
    return upsertProductResult;
  }

  @override
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    Money? priceOverride,
  }) async {
    upsertVariantCalls++;
    lastUpsertSize = size;
    lastUpsertColor = color;
    lastUpsertStock = stock;
    lastUpsertPriceOverride = priceOverride;
    final handler = upsertVariantHandler;
    if (handler != null) {
      return handler(
        productId: productId,
        size: size,
        color: color,
        stock: stock,
        priceOverride: priceOverride,
      );
    }
    return upsertVariantResult;
  }

  @override
  Future<Result<void>> adminSetProductImages(
      String productId, List<String> storagePaths) async {
    lastSavedImages = List.of(storagePaths);
    final handler = setImagesHandler;
    if (handler != null) return handler(productId, storagePaths);
    final failure = setImagesError;
    if (failure != null) throw failure;
    return setImagesResult;
  }

  @override
  Future<Result<List<AdminVariant>>> getVariants(String productId) async =>
      variantsResult;

  @override
  Future<Result<List<String>>> getProductImagePaths(String productId) async {
    imagePathReads++;
    return imagePathsResult;
  }

  @override
  Future<Result<List<AdminOrder>>> getAllOrders(
          {AdminOrderStatus? status, int limit = 50}) async =>
      ordersResult;

  @override
  Future<Result<AdminOrder?>> getOrderDetails(String orderId) async =>
      orderDetailsResult;

  @override
  Future<Result<void>> updateOrderStatus(
          String orderId, AdminOrderStatus status,
          {String? trackingNumber}) async =>
      orderStatusResult;

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts(
          {int threshold = 5}) async =>
      const Success(<LowStockVariant>[]);

  @override
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14}) async =>
      const Success(AdminSalesOverview(
        revenueByDay: [],
        topProducts: [],
        statusCounts: [],
      ));

  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) async =>
      tierResult;

  @override
  Future<Result<List<AdminCoupon>>> fetchCoupons() async =>
      const Success(<AdminCoupon>[]);

  @override
  Future<Result<AdminCoupon>> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  }) async =>
      const Failure(AppError('not implemented'));

  @override
  Future<Result<void>> setCouponActive(String id, bool active) async =>
      const Success(null);

  @override
  Future<Result<List<({String id, String product, String text, int rating})>>>
      fetchPendingReviews() async => pendingReviewsResult;

  @override
  Future<Result<void>> setReviewStatus(String id, String status) async =>
      reviewStatusResult;

  @override
  Future<Result<List<AdminWholesalePriceEntry>>> fetchWholesalePrices() async =>
      const Success(<AdminWholesalePriceEntry>[]);

  @override
  Future<Result<void>> upsertWholesalePrice(
          {required String productId, required int priceMinor}) async =>
      const Success(null);

  @override
  Future<Result<void>> deleteWholesalePrice(String productId) async =>
      const Success(null);

  @override
  Future<
      Result<
          ({
            List<AdminCustomer> customers,
            int? total,
            CustomerCursor? nextCursor,
          })>> fetchCustomers({
    String? query,
    CustomerCursor? cursor,
    int limit = defaultCustomersPageSize,
  }) async =>
      const Success((customers: <AdminCustomer>[], total: 0, nextCursor: null));
}
