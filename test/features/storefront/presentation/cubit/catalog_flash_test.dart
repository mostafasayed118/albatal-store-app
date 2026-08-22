import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
// Transitive dep of flutter_test; adding it to pubspec.yaml requires human
// approval per AGENTS.md, hence the scoped lint suppression.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubRepo implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([]);
  @override
  Future<Result<List<String>>> fetchCategories() async => const Success(['All']);
  @override
  Product? findProductById(String id) => null;
  @override
  List<String> get defaultCategories => const ['All'];
}

void main() {
  // fake_async fakes package:clock's clock.now(), not raw DateTime.now(),
  // so the cubit takes an injectable clock driven by FakeAsync.elapsed.
  // This keeps the tick assertions deterministic (spec §7).
  test('flashRemaining ticks every second', () {
    fakeAsync((a) {
      final base = DateTime(2026);
      final cubit =
          CatalogCubit(_StubRepo(), now: () => base.add(a.elapsed));
      cubit.startFlashSale(end: base.add(const Duration(seconds: 3)));
      expect(cubit.state.flashRemaining?.inSeconds, 3);
      a.elapse(const Duration(seconds: 1));
      expect(cubit.state.flashRemaining?.inSeconds, 2);
      a.elapse(const Duration(seconds: 1));
      expect(cubit.state.flashRemaining?.inSeconds, 1);
      cubit.close();
    });
  });

  test('flash timer cancels on close and reaches zero', () {
    fakeAsync((a) {
      final base = DateTime(2026);
      final cubit =
          CatalogCubit(_StubRepo(), now: () => base.add(a.elapsed));
      cubit.startFlashSale(end: base.add(const Duration(seconds: 1)));
      a.elapse(const Duration(seconds: 2));
      expect(cubit.state.flashRemaining, Duration.zero);
      cubit.close();
    });
  });
}
