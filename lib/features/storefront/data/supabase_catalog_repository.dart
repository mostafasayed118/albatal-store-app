import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';

/// Supabase-backed catalog repository.
///
/// Maps database rows to domain entities. The database stores money as
/// integer minor units (cents); [Money] carries that representation
/// through the domain and presentation layers without conversion.
class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<List<Product>>> fetchProducts() async {
    try {
      final response = await _client
          .from('products')
          .select('*, categories(name), product_variants(*)')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final products = (response as List).map((row) {
        final variants = (row['product_variants'] as List? ?? []);
        final categoryName = row['categories']?['name'] as String? ?? '';

        // Build stock map from variants
        final stock = <String, int>{};
        final sizes = <String>{};
        final colors = <String>{};
        for (final v in variants) {
          final size = v['size'] as String;
          final color = v['color'] as String;
          final stockQty = v['stock'] as int;
          sizes.add(size);
          colors.add(color);
          stock['$color-$size'] = stockQty;
        }

        // Fetch primary image
        final images = (row['product_images'] as List? ?? [])
            .map((img) => img['storage_path'] as String)
            .toList();
        final primaryImage = images.isNotEmpty ? images.first : null;

        return Product(
          id: row['id'] as String,
          name: row['name'] as String,
          category: categoryName,
          price: Money(row['base_price'] as int),
          oldPrice: row['old_price'] != null
              ? Money(row['old_price'] as int)
              : null,
          imageColor: _colorHash(categoryName),
          imageAsset: primaryImage,
          images: images,
          description: row['description'] as String?,
          composition: row['composition'] as String?,
          care: row['care'] as String?,
          origin: row['origin'] as String?,
          sizes: sizes.toList(),
          colors: colors.toList(),
          stock: stock,
          rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: row['review_count'] as int? ?? 0,
        );
      }).toList();

      return Success(products);
    } catch (e) {
      return Failure(AppError('Failed to load products: $e'));
    }
  }

  @override
  Future<Result<List<String>>> fetchCategories() async {
    try {
      final response = await _client
          .from('categories')
          .select('name')
          .eq('is_active', true)
          .order('sort_order');

      final categories = ['All'];
      categories.addAll(
          (response as List).map((row) => row['name'] as String));
      return Success(categories);
    } catch (e) {
      return Failure(AppError('Failed to load categories: $e'));
    }
  }

  /// Simple hash of a category name to a color int for placeholder swatches.
  int _colorHash(String name) {
    const colors = [
      0xFF176B57, 0xFFC99A64, 0xFF302244, 0xFFD9C6A1,
      0xFF88715F, 0xFFB57A2A, 0xFF6FA39A, 0xFF6B1F2E, 0xFFE0CDA0,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}
