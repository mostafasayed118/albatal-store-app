import '../../../../core/entities/product.dart';

/// Abstraction for cart persistence.
///
/// Lives in the domain layer so the presentation Cubit never imports
/// from data. The data layer provides the concrete implementation.
abstract interface class CartRepository {
  Future<List<CartItem>> readCart(ProductLookup productForId);
  Future<void> writeCart(List<CartItem> items);
}

typedef ProductLookup = Product? Function(String id);
