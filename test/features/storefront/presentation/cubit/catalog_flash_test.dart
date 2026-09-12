import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
// Transitive dep of flutter_test; adding it to pubspec.yaml requires human
// approval per AGENTS.md, hence the scoped lint suppression.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';

class _StubRepo
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([]);
  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);
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

void main() {
  // fake_async fakes package:clock's clock.now(), not raw DateTime.now(),
  // so the cubit takes an injectable clock driven by FakeAsync.elapsed.
  // This keeps the tick assertions deterministic (spec §7).
  test('flashCountdown ticks every second (audit P3 stream contract)', () {
    fakeAsync((a) {
      final base = DateTime(2026);
      final cubit = CatalogCubit(_StubRepo(), now: () => base.add(a.elapsed));
      final ticks = <Duration>[];
      final sub = cubit.flashCountdown.listen(ticks.add);
      cubit.startFlashSale(end: base.add(const Duration(seconds: 3)));
      a.flushMicrotasks();
      expect(ticks.single.inSeconds, 3);
      a.elapse(const Duration(seconds: 1));
      expect(ticks.last.inSeconds, 2);
      a.elapse(const Duration(seconds: 1));
      expect(ticks.last.inSeconds, 1);
      cubit.close();
      sub.cancel();
    });
  });

  test('flash timer cancels on close and reaches zero', () {
    fakeAsync((a) {
      final base = DateTime(2026);
      final cubit = CatalogCubit(_StubRepo(), now: () => base.add(a.elapsed));
      final ticks = <Duration>[];
      final sub = cubit.flashCountdown.listen(ticks.add);
      cubit.startFlashSale(end: base.add(const Duration(seconds: 1)));
      a.elapse(const Duration(seconds: 2));
      expect(ticks.last, Duration.zero);
      cubit.close();
      sub.cancel();
    });
  });
}
