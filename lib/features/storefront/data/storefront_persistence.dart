import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/entities/address.dart';
import '../../../core/entities/money.dart';
import '../../../core/entities/order.dart';
import '../../../core/entities/product.dart';
import '../../../core/error/result.dart';
import '../../../shared/extensions/iterable_x.dart';
import '../domain/repositories/cart_repository.dart';
import '../domain/repositories/orders_repository.dart';
import '../domain/repositories/wishlist_repository.dart';

/// SharedPreferences-backed persistence for the storefront feature.
///
/// Used as a delegate by [LocalCartRepository], [LocalWishlistRepository],
/// and [LocalOrdersRepository]. Returns raw values — error catching and
/// [Result] wrapping happens at the repository boundary (per Clean
/// Architecture §1: "mapping logic belongs in the data layer"; the repo
/// is the boundary). Previously this class swallowed all errors and
/// returned empty data, which hid persistence failures from the
/// presentation layer.
final class LocalStorefrontPersistence {
  LocalStorefrontPersistence(this._preferences);

  static const _cartKey = 'storefront_cart_lines_v1';
  static const _wishlistKey = 'storefront_wishlist_ids_v1';
  static const _ordersKey = 'storefront_orders_v1';
  final SharedPreferences _preferences;

  /// Maximum number of orders kept in local storage. Orders beyond
  /// this limit are fetched on demand from the server. Prevents the
  /// SharedPreferences JSON payload from growing unboundedly as order
  /// history accumulates.
  static const maxLocalOrders = 50;

  Future<List<CartItem>> readCart(ProductLookup productForId) async {
    final raw = _preferences.getString(_cartKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((line) {
          final product = productForId(line['productId'] as String? ?? '');
          final color = line['color'];
          final length = line['length'];
          final quantity = line['quantity'];
          if (product == null ||
              color is! String ||
              length is! String ||
              quantity is! num) {
            return null;
          }
          return CartItem(
            product: product,
            color: color,
            length: length,
            quantity: quantity.toInt().clamp(1, 99).toInt(),
          );
        })
        .whereType<CartItem>()
        .toList();
  }

  Future<Set<String>> readWishlist() async {
    final raw = _preferences.getString(_wishlistKey);
    if (raw == null) return <String>{};
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.whereType<String>().toSet() : <String>{};
  }

  Future<void> writeCart(List<CartItem> items) async {
    await _preferences.setString(
      _cartKey,
      jsonEncode(items
          .map((item) => {
                'productId': item.product.id,
                'color': item.color,
                'length': item.length,
                'quantity': item.quantity,
              })
          .toList()),
    );
  }

  Future<void> writeWishlist(Set<String> ids) async {
    await _preferences.setString(
      _wishlistKey,
      jsonEncode(ids.toList()..sort()),
    );
  }

  Future<List<Order>> readOrders() async {
    final raw = _preferences.getString(_ordersKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(OrderCodec.decode)
        .whereType<Order>()
        .toList();
  }

  Future<void> writeOrders(List<Order> orders) async {
    // Keep only the most recent orders locally. Older orders are fetched
    // on demand from the server via the order history RPC. This prevents
    // the JSON payload from growing quadratically with order history.
    final toStore = orders.length > maxLocalOrders
        ? orders.sublist(0, maxLocalOrders)
        : orders;
    await _preferences.setString(
      _ordersKey,
      jsonEncode(toStore.map(OrderCodec.encode).toList()),
    );
  }
}

/// In-memory test double for the storefront persistence layer.
///
/// Implements the three repository interfaces directly (no internal
/// [LocalStorefrontPersistence] delegate) and returns [Success] for
/// every operation — the in-memory store cannot fail, so no [Failure]
/// path is exercised. Use this in cubit tests that need a working
/// persistence double without touching SharedPreferences.
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

/// Serializes [Order] to/from JSON for both persistence implementations.
///
/// Orders snapshot the full [Product] (not just an ID) so a historical order
/// stays correct if the catalog later changes price or removes a product. This
/// mirrors a paper receipt: line items are frozen at confirmation time.
extension OrderCodec on Order {
  static Map<String, Object?> encode(Order o) => {
        'id': o.id,
        'items': o.items
            .map((i) => {
                  'product': {
                    'id': i.product.id,
                    'name': i.product.name,
                    'category': i.product.category,
                    'price': i.product.price.minorUnits,
                    'imageColor': i.product.imageColor,
                    'imageAsset': i.product.imageAsset,
                    'oldPrice': i.product.oldPrice?.minorUnits,
                    'description': i.product.description,
                    'composition': i.product.composition,
                    'care': i.product.care,
                    'origin': i.product.origin,
                  },
                  'color': i.color,
                  'length': i.length,
                  'quantity': i.quantity,
                })
            .toList(),
        'subtotal': o.subtotal.minorUnits,
        'shipping': o.shipping.minorUnits,
        'total': o.total.minorUnits,
        'status': o.status.name,
        'placedAt': o.placedAt.toIso8601String(),
        'paymentMethod': o.paymentMethod,
        if (o.address != null)
          'address': {
            'id': o.address!.id,
            'recipient': o.address!.recipient,
            'line': o.address!.line,
            'city': o.address!.city,
            'country': o.address!.country,
            'isDefault': o.address!.isDefault,
          },
      };

  static Order? decode(Map<Object?, Object?> raw) {
    final itemsRaw = raw['items'];
    if (itemsRaw is! List) return null;
    final items = itemsRaw
        .whereType<Map>()
        .map((line) {
          final pRaw = line['product'];
          if (pRaw is! Map) return null;
          final product = Product(
            id: pRaw['id'] as String,
            name: pRaw['name'] as String,
            category: pRaw['category'] as String,
            price: Money((pRaw['price'] as num).toInt()),
            imageColor: (pRaw['imageColor'] as num).toInt(),
            imageAsset: pRaw['imageAsset'] as String?,
            oldPrice: pRaw['oldPrice'] == null
                ? null
                : Money((pRaw['oldPrice'] as num).toInt()),
            description: pRaw['description'] as String?,
            composition: pRaw['composition'] as String?,
            care: pRaw['care'] as String?,
            origin: pRaw['origin'] as String?,
          );
          return CartItem(
            product: product,
            color: line['color'] as String,
            length: line['length'] as String,
            quantity: (line['quantity'] as num).toInt().clamp(1, 99).toInt(),
          );
        })
        .whereType<CartItem>()
        .toList();
    final status =
        OrderStatus.values.where((s) => s.name == raw['status']).firstOrNull;
    if (status == null) return null;
    return Order(
      id: raw['id'] as String,
      items: items,
      subtotal: Money((raw['subtotal'] as num).toInt()),
      shipping: Money((raw['shipping'] as num).toInt()),
      total: Money((raw['total'] as num).toInt()),
      status: status,
      placedAt: DateTime.parse(raw['placedAt'] as String),
      paymentMethod: raw['paymentMethod'] as String,
      address: raw['address'] != null
          ? Address(
              id: (raw['address'] as Map)['id'] as String,
              recipient: (raw['address'] as Map)['recipient'] as String,
              line: (raw['address'] as Map)['line'] as String,
              city: (raw['address'] as Map)['city'] as String,
              country: (raw['address'] as Map)['country'] as String? ?? '',
              isDefault: (raw['address'] as Map)['isDefault'] as bool? ?? false,
            )
          : null,
    );
  }
}
