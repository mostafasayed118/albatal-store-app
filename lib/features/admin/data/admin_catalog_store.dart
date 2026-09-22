import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../domain/entities/admin_catalog.dart';
import '../domain/entities/admin_variant.dart';
import '../domain/repositories/admin_catalog_port.dart';
import 'admin_mappers.dart';

/// Catalog management reads/writes for [SupabaseAdminRepository].
///
/// Implements [AdminCatalogPort] against Supabase; the facade keeps the
/// `AdminRepository` surface and delegates here unchanged.
final class SupabaseAdminCatalog implements AdminCatalogPort {
  SupabaseAdminCatalog({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<void>> updateStock(String variantId, int newStock) =>
      Result.guard<void>(() async {
        await _client
            .from('product_variants')
            .update({'stock': newStock}).eq('id', variantId);
      }, 'Failed to update stock', code: kAdminStockUpdateFailed);

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() => Result.guard(() async {
        // Bounded like the storefront fetchProducts(limit: 100) so a large
        // products table cannot stall the admin list: first 100 rows by
        // name via an explicit range page (audit residual P4).
        final rows = await _client
            .from('products')
            .select('id, name, slug, description, composition, category_id, '
                'base_price, is_active, categories(name)')
            .order('name')
            .limit(100)
            .range(0, 99);
        return AdminMappers.productsFromRows(rows as List<dynamic>);
      }, 'Failed to load products', code: kAdminProductsLoadFailed);

  @override
  Future<Result<AdminProduct?>> getProductById(String productId) =>
      Result.guard(() async {
        final rows = await _client
            .from('products')
            .select('id, name, slug, description, composition, category_id, '
                'base_price, is_active, categories(name)')
            .eq('id', productId)
            .limit(1);
        final list = rows as List<dynamic>;
        if (list.isEmpty) return null;
        return AdminMappers.productsFromRows(list).first;
      }, 'Failed to load product', code: kAdminProductLoadFailed);

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() =>
      Result.guard(() async {
        final rows = await _client
            .from('categories')
            .select('id, name, is_active')
            .order('sort_order');
        return AdminMappers.categoriesFromRows(rows as List<dynamic>);
      }, 'Failed to load categories', code: kAdminCategoriesLoadFailed);

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
    required double basePrice,
    required bool isActive,
  }) =>
      Result.guard<String>(() async {
        final res = await _client.rpc('admin_upsert_product', params: {
          'p_id': id,
          'p_name': name,
          'p_slug': slug,
          'p_description': description,
          'p_composition': composition,
          'p_category_id': categoryId,
          'p_base_price': basePrice,
          'p_is_active': isActive,
          // §10 fabric attributes: only sent when set — the pre-051 RPC
          // rejects unknown named parameters.
          if (care != null) 'p_care': care,
          if (origin != null) 'p_origin': origin,
          if (widthCm != null) 'p_width_cm': widthCm,
          if (gsm != null) 'p_gsm': gsm,
          if (sellByLength != null) 'p_sell_by_length': sellByLength,
          if (minCutMeters != null) 'p_min_cut_meters': minCutMeters,
        });
        if (res is! String || res.isEmpty) {
          // An RPC that answers without the product id is a protocol
          // violation, not a transport error — but it is reported with the
          // same message the boundary uses, so the text stays byte-identical
          // and the empty payload rides along as the cause.
          throw StateError('admin_upsert_product returned no product id');
        }
        return res;
      }, 'Failed to save product', code: kAdminProductSaveFailed);

  @override
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  }) =>
      Result.guard<String>(() async {
        final res = await _client.rpc('admin_upsert_variant', params: {
          'p_product_id': productId,
          'p_size': size,
          'p_color': color,
          'p_stock': stock,
          'p_price_override': priceOverride,
        });
        if (res is! String || res.isEmpty) {
          // Same protocol-violation shape as [adminUpsertProduct]: message
          // text unchanged, empty payload recorded as the cause.
          throw StateError('admin_upsert_variant returned no variant id');
        }
        return res;
      }, 'Failed to save variant', code: kAdminVariantSaveFailed);

  @override
  Future<Result<void>> adminSetProductImages(
          String productId, List<String> storagePaths) =>
      Result.guard<void>(() async {
        await _client.rpc('admin_set_product_images', params: {
          'p_product_id': productId,
          'p_paths': storagePaths,
        });
      }, 'Failed to save images', code: kAdminImagesSaveFailed);

  @override
  Future<Result<List<AdminVariant>>> getVariants(String productId) =>
      Result.guard(() async {
        final res = await _client
            .from('product_variants')
            // Explicit columns (audit P6): only what
            // [AdminMappers.variantFromRow] reads — never `*`.
            .select('id, size, color, stock, price_override')
            .eq('product_id', productId)
            .order('size');
        return AdminMappers.variantsFromRows(res as List);
      }, 'Failed to load variants', code: kAdminVariantsLoadFailed);

  @override
  Future<Result<List<String>>> getProductImagePaths(String productId) =>
      Result.guard(() async {
        final res = await _client
            .from('product_images')
            .select('storage_path')
            .eq('product_id', productId)
            .order('sort_order');
        return AdminMappers.imagePathsFromRows(res as List);
      }, 'Failed to load images', code: kAdminImagesLoadFailed);
}
