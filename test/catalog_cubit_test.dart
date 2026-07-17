import 'package:al_batal_elite/features/storefront/presentation/cubit/storefront_cubits.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  blocTest<CatalogCubit, CatalogState>(
    'filters catalog results by a case-insensitive product query',
    build: CatalogCubit.new,
    act: (cubit) => cubit.updateQuery('VELVET'),
    expect: () => [const CatalogState(query: 'VELVET')],
    verify: (cubit) {
      expect(cubit.state.visible, hasLength(1));
      expect(cubit.state.visible.single.name, 'Midnight Velvet');
    },
  );

  blocTest<CatalogCubit, CatalogState>(
    'orders the full catalog by descending price',
    build: CatalogCubit.new,
    act: (cubit) => cubit.selectSort(CatalogSort.priceHighToLow),
    expect: () => [const CatalogState(sort: CatalogSort.priceHighToLow)],
    verify: (cubit) => expect(
      cubit.state.visible.map((product) => product.price),
      [1290, 980, 820, 690, 540],
    ),
  );

  blocTest<CatalogCubit, CatalogState>(
    'clears query, category, and sorting together',
    build: CatalogCubit.new,
    act: (cubit) {
      cubit.updateQuery('silk');
      cubit.select('Silk');
      cubit.selectSort(CatalogSort.name);
      cubit.clearFilters();
    },
    expect: () => [
      const CatalogState(query: 'silk'),
      const CatalogState(category: 'Silk', query: 'silk'),
      const CatalogState(category: 'Silk', query: 'silk', sort: CatalogSort.name),
      const CatalogState(),
    ],
  );
}
