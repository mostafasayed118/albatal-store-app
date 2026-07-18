import '../../../core/entities/product.dart';
import '../domain/repositories/cart_repository.dart';
import 'storefront_persistence.dart';

/// Data-layer implementation of [CartRepository].
///
/// Delegates to [StorefrontPersistence] which handles the actual
/// SharedPreferences read/write. This indirection lets the domain
/// layer stay free of persistence details.
final class LocalCartRepository implements CartRepository {
  LocalCartRepository(this._persistence);
  final StorefrontPersistence _persistence;

  @override
  Future<List<CartItem>> readCart(ProductLookup productForId) =>
      _persistence.readCart(productForId);

  @override
  Future<void> writeCart(List<CartItem> items) =>
      _persistence.writeCart(items);
}
