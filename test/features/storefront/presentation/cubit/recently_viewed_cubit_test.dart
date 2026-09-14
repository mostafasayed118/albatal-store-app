import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recently_viewed_store.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/recently_viewed_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryStore implements RecentlyViewedStore {
  final List<Product> _entries = [];

  @override
  List<Product> load() => List.of(_entries);

  @override
  void record(Product product) {
    _entries.removeWhere((e) => e.id == product.id);
    _entries.insert(0, product);
  }

  @override
  void clear() => _entries.clear();
}

const _silk = Product(
  id: 'silk',
  name: 'Silk',
  category: 'Silk',
  price: Money.egp(1290),
  imageColor: 0xFF004D40,
);

void main() {
  group('RecentlyViewedCubit', () {
    blocTest<RecentlyViewedCubit, RecentlyViewedState>(
      'record surfaces the product in state',
      build: () => RecentlyViewedCubit(store: _MemoryStore()),
      act: (cubit) => cubit.record(_silk),
      expect: () => [
        const RecentlyViewedState(products: [_silk])
      ],
    );

    blocTest<RecentlyViewedCubit, RecentlyViewedState>(
      'clear empties state',
      build: () => RecentlyViewedCubit(store: _MemoryStore()),
      seed: () => const RecentlyViewedState(products: [_silk]),
      act: (cubit) => cubit.clear(),
      expect: () => [const RecentlyViewedState()],
    );
  });
}
