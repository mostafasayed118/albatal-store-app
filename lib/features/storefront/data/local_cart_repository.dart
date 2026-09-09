import '../../../core/entities/product.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/cart_repository.dart';
import 'storefront_persistence.dart';

/// Data-layer implementation of [CartRepository].
///
/// Delegates to [LocalStorefrontPersistence] for the actual
/// SharedPreferences read/write, and catches errors at this boundary
/// per Clean Architecture §1 ("mapping logic belongs in the data layer").
/// The presentation Cubit only ever sees [Result] — never an exception.
final class LocalCartRepository implements CartRepository {
  LocalCartRepository(this._persistence);
  final LocalStorefrontPersistence _persistence;

  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) =>
      Result.guard(
          () => _persistence.readCart(productForId), 'Failed to load cart');

  @override
  Future<Result<void>> writeCart(List<CartItem> items) => Result.guard<void>(
        () => _persistence.writeCart(items),
        'Failed to save cart',
      );
}
