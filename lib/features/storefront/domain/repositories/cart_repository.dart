import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';

/// Abstraction for cart persistence.
///
/// Lives in the domain layer so the presentation Cubit never imports
/// from data. The data layer provides the concrete implementation.
/// Returns [Result] so callers receive errors at this boundary instead
/// of having to catch exceptions themselves.
abstract interface class CartRepository {
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId);
  Future<Result<void>> writeCart(List<CartItem> items);
}

typedef ProductLookup = Product? Function(String id);
