import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/shared/services/connectivity_gate.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';

/// Task #8 offline-catalog: cubit behaviour when the ConnectivityGate
/// reports offline. The gate is seeded via its `@visibleForTesting`
/// constructor — no plugin stack is started.

final class _WarmRepo
    with FetchRelatedFromProducts
    implements CatalogRepository {
  const _WarmRepo();

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    final product = products.where((p) => p.id == id).firstOrNull;
    if (product != null) return Success(product);
    return const Failure(AppError('Product not found'));
  }

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => categories;

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

final class _ColdRepo
    with FetchRelatedFromProducts
    implements CatalogRepository {
  const _ColdRepo();

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Failure(AppError('Catalog unavailable'));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Failure(AppError('Catalog unavailable'));

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('Product not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

/// Product resolves but the related strip query explodes — models a
/// network probe that dies between the two details fetches.
final class _RelatedFailsRepo extends _WarmRepo {
  const _RelatedFailsRepo();

  @override
  Future<Result<List<Product>>> fetchRelated(
    String category, {
    String? excludeId,
    int limit = 8,
  }) async =>
      const Failure(AppError('Related unavailable'));
}

void main() {
  group('CatalogCubit — offline load (Task #8)', () {
    blocTest<CatalogCubit, CatalogState>(
      'offline + warm cache reaches ready and is tagged isOffline',
      build: () => CatalogCubit(const _WarmRepo(),
          gate: ConnectivityGate(seedOnline: false)),
      act: (cubit) => cubit.load(),
      expect: () => [
        CatalogState(status: CatalogStatus.loading, isOffline: true),
        isA<CatalogState>()
            .having((s) => s.status, 'status', CatalogStatus.ready)
            .having((s) => s.isOffline, 'isOffline', isTrue)
            .having((s) => s.allProducts.length, 'products', 9),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'offline + cold cache errors with isOffline set — the page maps '
      'this to the offline notice, not a real failure',
      build: () => CatalogCubit(const _ColdRepo(),
          gate: ConnectivityGate(seedOnline: false)),
      act: (cubit) => cubit.load(),
      expect: () => [
        CatalogState(status: CatalogStatus.loading, isOffline: true),
        CatalogState(status: CatalogStatus.error, isOffline: true),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'online failure stays a real failure (isOffline false)',
      build: () => CatalogCubit(const _ColdRepo(),
          gate: ConnectivityGate(seedOnline: true)),
      act: (cubit) => cubit.load(),
      expect: () => [
        CatalogState(status: CatalogStatus.loading),
        CatalogState(status: CatalogStatus.error),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'no gate keeps the legacy online assumption',
      build: () => CatalogCubit(const _WarmRepo()),
      act: (cubit) => cubit.load(),
      expect: () => [
        CatalogState(status: CatalogStatus.loading),
        isA<CatalogState>()
            .having((s) => s.status, 'status', CatalogStatus.ready)
            .having((s) => s.isOffline, 'isOffline', isFalse),
      ],
    );
  });

  group('ProductDetailsCubit — offline degrade (Task #8)', () {
    blocTest<ProductDetailsCubit, DetailsState>(
      'offline + cached product resolves ready with isOffline set',
      build: () => ProductDetailsCubit(const _WarmRepo(),
          gate: ConnectivityGate(seedOnline: false)),
      act: (cubit) => cubit.loadProduct('silk-01'),
      expect: () => [
        const DetailsState(status: DetailsStatus.loading, isOffline: true),
        isA<DetailsState>()
            .having((s) => s.status, 'status', DetailsStatus.ready)
            .having((s) => s.isOffline, 'isOffline', isTrue)
            .having((s) => s.product?.id, 'product id', 'silk-01'),
      ],
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'offline + cold cache errors with isOffline set (not a real failure)',
      build: () => ProductDetailsCubit(const _ColdRepo(),
          gate: ConnectivityGate(seedOnline: false)),
      act: (cubit) => cubit.loadProduct('silk-01'),
      expect: () => [
        const DetailsState(status: DetailsStatus.loading, isOffline: true),
        const DetailsState(
          status: DetailsStatus.error,
          errorMessage: 'Unable to load product details.',
          isOffline: true,
        ),
      ],
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'a failed related fetch degrades to an empty strip, never an error',
      build: () => ProductDetailsCubit(const _RelatedFailsRepo(),
          gate: ConnectivityGate(seedOnline: false)),
      act: (cubit) => cubit.loadProduct('silk-01'),
      expect: () => [
        const DetailsState(status: DetailsStatus.loading, isOffline: true),
        isA<DetailsState>()
            .having((s) => s.status, 'status', DetailsStatus.ready)
            .having((s) => s.relatedProducts, 'related', isEmpty),
      ],
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'online failure stays a real failure (isOffline false)',
      build: () => ProductDetailsCubit(const _ColdRepo(),
          gate: ConnectivityGate(seedOnline: true)),
      act: (cubit) => cubit.loadProduct('silk-01'),
      expect: () => [
        const DetailsState(status: DetailsStatus.loading),
        const DetailsState(
          status: DetailsStatus.error,
          errorMessage: 'Unable to load product details.',
        ),
      ],
    );
  });
}
