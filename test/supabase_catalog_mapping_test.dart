import 'package:al_batal_elite/features/storefront/data/supabase_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for [SupabaseCatalogRepository]'s row → domain mapping,
/// exercised via the `@visibleForTesting` [debugMapProduct] hook so no
/// live Supabase client is required.
///
/// NOTE (staging-blocked): these tests prove the *mapping* only. Whether
/// real product images render on-device also depends on `product_images`
/// rows existing in the database and matching assets being uploaded to the
/// `product-images` Storage bucket — neither is verifiable here.
void main() {
  // Deterministic stand-in for Supabase Storage public URL generation.
  String publicUrlFor(String path) =>
      'https://cdn.example/product-images/$path';

  Map<String, dynamic> baseRow({
    List<Map<String, dynamic>> variants = const [],
    List<Map<String, dynamic>> images = const [],
  }) =>
      {
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'Emerald Silk',
        'base_price': 129000,
        'old_price': null,
        'rating': 4.5,
        'review_count': 12,
        'description': 'A fine silk.',
        'composition': '100% silk',
        'care': 'Dry clean',
        'origin': 'Egypt',
        'categories': {'name': 'Silk'},
        'product_variants': variants,
        'product_images': images,
      };

  group('SupabaseCatalogRepository.debugMapProduct image mapping', () {
    test('maps the primary image to imageAsset as a public URL', () {
      final product = SupabaseCatalogRepository.debugMapProduct(
        baseRow(),
        const [],
        const [
          {
            'storage_path': 'silk/secondary.jpg',
            'is_primary': false,
            'sort_order': 2
          },
          {
            'storage_path': 'silk/primary.jpg',
            'is_primary': true,
            'sort_order': 5
          },
        ],
        publicUrlFor,
      );

      expect(
        product.imageAsset,
        'https://cdn.example/product-images/silk/primary.jpg',
      );
      // Gallery keeps every resolved image, primary first.
      expect(product.images, [
        'https://cdn.example/product-images/silk/primary.jpg',
        'https://cdn.example/product-images/silk/secondary.jpg',
      ]);
    });

    test('falls back to sort_order when no image is flagged primary', () {
      final product = SupabaseCatalogRepository.debugMapProduct(
        baseRow(),
        const [],
        const [
          {'storage_path': 'b.jpg', 'is_primary': false, 'sort_order': 3},
          {'storage_path': 'a.jpg', 'is_primary': false, 'sort_order': 1},
        ],
        publicUrlFor,
      );

      expect(product.imageAsset, 'https://cdn.example/product-images/a.jpg');
    });

    test('leaves imageAsset null and images empty when no images exist', () {
      final product = SupabaseCatalogRepository.debugMapProduct(
        baseRow(),
        const [],
        const [],
        publicUrlFor,
      );

      expect(product.imageAsset, isNull);
      expect(product.images, isEmpty);
      // The presentation fallback colour is still present.
      expect(product.imageColor, 0xFF888888);
    });

    test('ignores image rows with a blank storage_path', () {
      final product = SupabaseCatalogRepository.debugMapProduct(
        baseRow(),
        const [],
        const [
          {'storage_path': '   ', 'is_primary': true, 'sort_order': 0},
          {'storage_path': 'real.jpg', 'is_primary': false, 'sort_order': 1},
        ],
        publicUrlFor,
      );

      expect(product.imageAsset, 'https://cdn.example/product-images/real.jpg');
      expect(product.images, ['https://cdn.example/product-images/real.jpg']);
    });

    test('derives variant sizes, colors, and stock map', () {
      final product = SupabaseCatalogRepository.debugMapProduct(
        baseRow(variants: const [
          {'size': '2m', 'color': 'Emerald', 'stock': 4},
          {'size': '5m', 'color': 'Gold', 'stock': 0},
        ]),
        const [
          {'size': '2m', 'color': 'Emerald', 'stock': 4},
          {'size': '5m', 'color': 'Gold', 'stock': 0},
        ],
        const [],
        publicUrlFor,
      );

      expect(product.sizes, containsAll(['2m', '5m']));
      expect(product.colors, containsAll(['Emerald', 'Gold']));
      expect(product.stockFor('Emerald', '2m'), 4);
      expect(product.stockFor('Gold', '5m'), 0);
    });
  });
}
