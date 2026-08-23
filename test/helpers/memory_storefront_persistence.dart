import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart'
    show OrderCodec;
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';

/// In-memory test double for the storefront persistence layer.
///
/// Implements the three repository interfaces directly (no internal
/// [LocalStorefrontPersistence] delegate) and returns [Success] for
/// every operation — the in-memory store cannot fail, so no [Failure]
/// path is exercised. Use this in cubit tests that need a working
/// persistence double without touching SharedPreferences.
///
/// Lives in `test/` so it never ships in the production binary.
final class MemoryStorefrontPersistence
    implements CartRepository, WishlistRepository, OrdersRepository {
  List<Map<String, Object>> cartLines = [];
  Set<String> wishlistIds = {};
  List<Map<String, Object?>> orderRecords = [];

  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      Success(cartLines
          .map((line) {
            final product = productForId(line['productId'] as String? ?? '');
            return product == null
                ? null
                : CartItem(
                    product: product,
                    color: line['color']! as String,
                    length: line['length']! as String,
                    quantity: line['quantity']! as int,
                  );
          })
          .whereType<CartItem>()
          .toList());

  @override
  Future<Result<Set<String>>> readWishlist() async => Success({...wishlistIds});

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async {
    cartLines = items
        .map((item) => <String, Object>{
              'productId': item.product.id,
              'color': item.color,
              'length': item.length,
              'quantity': item.quantity,
            })
        .toList();
    return const Success(null);
  }

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async {
    wishlistIds = {...ids};
    return const Success(null);
  }

  @override
  Future<Result<List<Order>>> readOrders() async =>
      Success(orderRecords.map(OrderCodec.decode).whereType<Order>().toList());

  @override
  Future<Result<void>> writeOrders(List<Order> orders) async {
    orderRecords = orders.map(OrderCodec.encode).toList();
    return const Success(null);
  }
}
