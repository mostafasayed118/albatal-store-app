import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubCatalogRepo implements CatalogRepository {
  _StubCatalogRepo(this.product);
  final Product? product;

  @override
  Product? findProductById(String id) => product;

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Success(product!);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Product _fabric({bool sellByLength = true, double? minCut = 1.0}) => Product(
      id: 'p1',
      name: 'Silk Roll',
      category: 'Silk',
      price: const Money(12000),
      imageColor: 0xFF064E3B,
      sellByLength: sellByLength,
      minCutMeters: minCut,
      widthCm: 150,
      gsm: 90,
    );

void main() {
  group('product mapper fabric fields (§10)', () {
    test('reads width/gsm/sell_by_length/min_cut', () {
      final product = ProductCodec.fromRow(
        {
          'id': 'p1',
          'name': 'Silk Roll',
          'category': 'Silk',
          'base_price': 12000,
          'image_color': 0xFF064E3B,
          'width_cm': 150,
          'gsm': 90,
          'sell_by_length': true,
          'min_cut_meters': 1.5,
        },
        const [],
        storageService: StorageService(client: null),
      )!;
      expect(product.widthCm, 150);
      expect(product.gsm, 90);
      expect(product.sellByLength, isTrue);
      expect(product.minCutMeters, 1.5);
    });

    test('defaults degrade gracefully when columns absent', () {
      final product = ProductCodec.fromRow(
        {
          'id': 'p1',
          'name': 'Silk Roll',
          'category': 'Silk',
          'base_price': 12000,
          'image_color': 0xFF064E3B,
        },
        const [],
        storageService: StorageService(client: null),
      )!;
      expect(product.widthCm, isNull);
      expect(product.gsm, isNull);
      expect(product.sellByLength, isFalse);
      expect(product.minCutMeters, isNull);
    });
  });

  group('ProductDetailsCubit.setCutLength (§10)', () {
    Future<ProductDetailsCubit> cubitWith(Product product) async {
      final cubit = ProductDetailsCubit(_StubCatalogRepo(product));
      await cubit.loadProduct(product.id);
      return cubit;
    }

    test('clamps below min cut and snaps to 0.5 m', () async {
      final cubit = await cubitWith(_fabric(minCut: 1.0));
      cubit.setCutLength(0.4);
      expect(cubit.state.length, '1.0');
      cubit.setCutLength(2.3);
      expect(cubit.state.length, '2.5');
      await cubit.close();
    });

    test('clamps at the 50 m ceiling and stays on the 0.5 m grid', () async {
      final cubit = await cubitWith(_fabric(minCut: 1.0));
      cubit.setCutLength(999);
      expect(cubit.state.length, '50.0');
      cubit.setCutLength(50.3);
      expect(cubit.state.length, '50.0');
      await cubit.close();
    });

    test('ignores non-sell-by-length products', () async {
      final cubit = await cubitWith(_fabric(sellByLength: false, minCut: null));
      final before = cubit.state.length;
      cubit.setCutLength(3.0);
      expect(cubit.state.length, before);
      await cubit.close();
    });
  });
}
