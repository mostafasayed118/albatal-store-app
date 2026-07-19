import '../../../core/entities/product.dart';
import '../../../core/error/app_error.dart';
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
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async {
    try {
      return Success(await _persistence.readCart(productForId));
    } catch (e) {
      return Failure(AppError('Failed to load cart', cause: e));
    }
  }

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async {
    try {
      await _persistence.writeCart(items);
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to save cart', cause: e));
    }
  }
}
