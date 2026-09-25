import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_coupon.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_sales.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_variant.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_sales_dashboard_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-rolled fake (mocktail-free, matching the catalog-page test
/// convention): every read returns canned successes; the two dashboard
/// feeds are configurable per test.
class _FakeAdminRepository implements AdminRepository {
  Result<AdminSalesOverview> overviewResult = const Success(AdminSalesOverview(
    revenueByDay: [],
    topProducts: [],
    statusCounts: [],
  ));

  Result<List<LowStockVariant>> lowStockResult = const Success([]);

  @override
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14}) async =>
      overviewResult;

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts(
          {int threshold = 5}) async =>
      lowStockResult;

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
  Future<Result<void>> updateStock(String variantId, int newStock) async =>
      const Success(null);

  @override
  Future<Result<List<AdminCoupon>>> fetchCoupons() async => const Success([]);

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

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() async =>
      const Success([]);

  @override
  Future<Result<AdminProduct?>> getProductById(String productId) async =>
      const Success(null);

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() async =>
      const Success([]);

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
  }) async =>
      const Success('fake');

  @override
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    Money? priceOverride,
  }) async =>
      const Success('fake');

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

  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) async =>
      const Success(null);

  @override
  Future<Result<List<({String id, String product, String text, int rating})>>>
      fetchPendingReviews() async => const Success([]);

  @override
  Future<Result<void>> setReviewStatus(String id, String status) async =>
      const Success(null);
}

AdminSalesOverview _overview() => AdminSalesOverview(
      revenueByDay: [
        AdminRevenuePoint(day: DateTime.utc(2026, 9, 12), revenueMinor: 129000),
        AdminRevenuePoint(day: DateTime.utc(2026, 9, 13), revenueMinor: 45000),
      ],
      topProducts: const [
        AdminTopProduct(productName: 'Emerald Silk', unitsSold: 7),
      ],
      statusCounts: const [
        AdminSalesStatusCount(status: AdminOrderStatus.paid, count: 3),
      ],
    );

void main() {
  group('AdminSalesDashboardCubit.load', () {
    blocTest<AdminSalesDashboardCubit, AdminSalesDashboardState>(
      'emits loading then loaded with overview and low stock on Success',
      build: () {
        final repo = _FakeAdminRepository()
          ..overviewResult = Success(_overview())
          ..lowStockResult = const Success([
            LowStockVariant(
              variantId: 'v1',
              productName: 'Emerald Silk',
              size: '1m',
              color: 'Emerald',
              stock: 2,
            ),
          ]);
        return AdminSalesDashboardCubit(repository: repo);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminSalesDashboardState>().having(
            (s) => s.status, 'status', AdminSalesDashboardStatus.loading),
        isA<AdminSalesDashboardState>()
            .having((s) => s.status, 'status', AdminSalesDashboardStatus.loaded)
            .having((s) => s.overview, 'overview', isNotNull)
            .having((s) => s.overview!.revenueByDay.length,
                'overview.revenueByDay.length', 2)
            .having((s) => s.overview!.topProducts.single.unitsSold,
                'topProduct.unitsSold', 7)
            .having(
                (s) => s.lowStock.single.variantId, 'lowStock.variantId', 'v1'),
      ],
    );

    blocTest<AdminSalesDashboardCubit, AdminSalesDashboardState>(
      'emits error with repository message and code on overview Failure',
      build: () {
        final repo = _FakeAdminRepository()
          ..overviewResult = const Failure(AppError(
              'Failed to load sales overview',
              code: kAdminSalesLoadFailed))
          ..lowStockResult = const Success([]);
        return AdminSalesDashboardCubit(repository: repo);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminSalesDashboardState>().having(
            (s) => s.status, 'status', AdminSalesDashboardStatus.loading),
        isA<AdminSalesDashboardState>()
            .having((s) => s.status, 'status', AdminSalesDashboardStatus.error)
            .having((s) => s.errorMessage, 'errorMessage',
                'Failed to load sales overview')
            .having((s) => s.errorCode, 'errorCode', kAdminSalesLoadFailed),
      ],
    );

    blocTest<AdminSalesDashboardCubit, AdminSalesDashboardState>(
      'degrades to an empty low-stock panel when only low stock fails',
      build: () {
        final repo = _FakeAdminRepository()
          ..overviewResult = Success(_overview())
          ..lowStockResult =
              const Failure(AppError('Failed to load low stock products'));
        return AdminSalesDashboardCubit(repository: repo);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminSalesDashboardState>().having(
            (s) => s.status, 'status', AdminSalesDashboardStatus.loading),
        isA<AdminSalesDashboardState>()
            .having((s) => s.status, 'status', AdminSalesDashboardStatus.loaded)
            .having((s) => s.overview, 'overview', isNotNull)
            .having((s) => s.lowStock, 'lowStock', isEmpty),
      ],
    );
  });
}
