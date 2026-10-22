import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/product_edit_loaders.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_only_admin_repository.dart';

void main() {
  late TestOnlyAdminRepository repo;

  setUp(() {
    repo = TestOnlyAdminRepository();
  });

  group('loadProductEditCategories', () {
    test('keeps a vanished selection as an id-named selectable entry',
        () async {
      repo.categoriesResult = const Success(<AdminCategory>[
        AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
      ]);

      final loaded = await loadProductEditCategories(
        repository: repo,
        selectedCategoryId: 'c-old',
      );

      expect(loaded.selectedId, 'c-old');
      expect(loaded.categories.map((c) => c.id), ['c-1', 'c-old']);
      expect(loaded.categories.last.name, 'c-old');
    });

    test('auto-selects the first category when nothing is selected yet',
        () async {
      repo.categoriesResult = const Success(<AdminCategory>[
        AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
        AdminCategory(id: 'c-2', name: 'Cotton', isActive: true),
      ]);

      final loaded = await loadProductEditCategories(
        repository: repo,
        selectedCategoryId: null,
      );

      expect(loaded.selectedId, 'c-1');
      expect(loaded.categories, hasLength(2));
    });

    test('keeps a selection that is still present without duplicating it',
        () async {
      repo.categoriesResult = const Success(<AdminCategory>[
        AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
        AdminCategory(id: 'c-2', name: 'Cotton', isActive: true),
      ]);

      final loaded = await loadProductEditCategories(
        repository: repo,
        selectedCategoryId: 'c-2',
      );

      expect(loaded.selectedId, 'c-2');
      expect(loaded.categories.map((c) => c.id), ['c-1', 'c-2']);
    });

    test('an empty list with no selection stays empty', () async {
      final loaded = await loadProductEditCategories(
        repository: repo,
        selectedCategoryId: null,
      );

      expect(loaded.categories, isEmpty);
      expect(loaded.selectedId, isNull);
    });

    test('a failed read degrades to the selection as its own name', () async {
      repo.categoriesResult = const Failure(AppError('categories unavailable'));

      final loaded = await loadProductEditCategories(
        repository: repo,
        selectedCategoryId: 'c-1',
      );

      expect(loaded.selectedId, 'c-1');
      expect(loaded.categories.single.id, 'c-1');
      expect(loaded.categories.single.name, 'c-1');
    });

    test('a failed read with no selection degrades to an empty list', () async {
      repo.categoriesResult = const Failure(AppError('categories unavailable'));

      final loaded = await loadProductEditCategories(
        repository: repo,
        selectedCategoryId: null,
      );

      expect(loaded.categories, isEmpty);
      expect(loaded.selectedId, isNull);
    });

    test('a throwing read is caught and degrades the same way', () async {
      repo.categoriesError = StateError('boom');

      final loaded = await loadProductEditCategories(
        repository: repo,
        selectedCategoryId: 'c-9',
      );

      expect(loaded.selectedId, 'c-9');
      expect(loaded.categories.single.name, 'c-9');
    });
  });

  group('fetchProductForEdit', () {
    test('returns the product on success', () async {
      repo.productByIdResult = const Success(AdminProduct(
        id: 'p-1',
        name: 'Silk',
        slug: 'silk',
        categoryId: 'c-1',
        categoryName: 'Silk',
        basePrice: Money.egp(100),
        isActive: true,
      ));

      final loaded = await fetchProductForEdit(
        repository: repo,
        productId: 'p-1',
      );

      expect(loaded.product?.id, 'p-1');
      expect(loaded.failureCode, isNull);
      expect(loaded.failureMessage, isNull);
    });

    test('a success with no row returns a null product and no failure',
        () async {
      final loaded = await fetchProductForEdit(
        repository: repo,
        productId: 'missing',
      );

      expect(loaded.product, isNull);
      expect(loaded.failureCode, isNull);
      expect(loaded.failureMessage, isNull);
    });

    test('a failure carries the code and message for the page to render',
        () async {
      repo.productByIdResult = const Failure(AppError('single fetch failed'));

      final loaded = await fetchProductForEdit(
        repository: repo,
        productId: 'p-1',
      );

      expect(loaded.product, isNull);
      expect(loaded.failureMessage, 'single fetch failed');
    });
  });
}
