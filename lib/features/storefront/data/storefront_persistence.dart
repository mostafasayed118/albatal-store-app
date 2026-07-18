import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/entities/order.dart';
import '../../../core/entities/product.dart';

typedef ProductLookup = Product? Function(String id);

abstract interface class StorefrontPersistence {
  Future<List<CartItem>> readCart(ProductLookup productForId);
  Future<Set<String>> readWishlist();
  Future<void> writeCart(List<CartItem> items);
  Future<void> writeWishlist(Set<String> ids);
  Future<List<Order>> readOrders();
  Future<void> writeOrders(List<Order> orders);
}

final class LocalStorefrontPersistence implements StorefrontPersistence {
  LocalStorefrontPersistence(this._preferences);

  static const _cartKey = 'storefront_cart_lines_v1';
  static const _wishlistKey = 'storefront_wishlist_ids_v1';
  static const _ordersKey = 'storefront_orders_v1';
  final SharedPreferences _preferences;

  @override
  Future<List<CartItem>> readCart(ProductLookup productForId) async {
    try {
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
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Set<String>> readWishlist() async {
    try {
      final raw = _preferences.getString(_wishlistKey);
      if (raw == null) return <String>{};
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.whereType<String>().toSet() : <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<void> writeCart(List<CartItem> items) => _write(
        _cartKey,
        items
            .map((item) => {
                  'productId': item.product.id,
                  'color': item.color,
                  'length': item.length,
                  'quantity': item.quantity,
                })
            .toList(),
      );

  @override
  Future<void> writeWishlist(Set<String> ids) =>
      _write(_wishlistKey, ids.toList()..sort());

  @override
  Future<List<Order>> readOrders() async {
    try {
      final raw = _preferences.getString(_ordersKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(OrderCodec.decode)
          .whereType<Order>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> writeOrders(List<Order> orders) =>
      _write(_ordersKey, orders.map(OrderCodec.encode).toList());

  Future<void> _write(String key, Object value) async {
    try {
      await _preferences.setString(key, jsonEncode(value));
    } catch (_) {
      // Local state remains usable if device storage is unavailable.
    }
  }
}

final class MemoryStorefrontPersistence implements StorefrontPersistence {
  List<Map<String, Object>> cartLines = [];
  Set<String> wishlistIds = {};
  List<Map<String, Object?>> orderRecords = [];

  @override
  Future<List<CartItem>> readCart(ProductLookup productForId) async => cartLines
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
      .toList();

  @override
  Future<Set<String>> readWishlist() async => {...wishlistIds};

  @override
  Future<void> writeCart(List<CartItem> items) async {
    cartLines = items
        .map((item) => <String, Object>{
              'productId': item.product.id,
              'color': item.color,
              'length': item.length,
              'quantity': item.quantity,
            })
        .toList();
  }

  @override
  Future<void> writeWishlist(Set<String> ids) async => wishlistIds = {...ids};

  @override
  Future<List<Order>> readOrders() async =>
      orderRecords.map(OrderCodec.decode).whereType<Order>().toList();

  @override
  Future<void> writeOrders(List<Order> orders) async =>
      orderRecords = orders.map(OrderCodec.encode).toList();
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
                    'price': i.product.price,
                  'imageColor': i.product.imageColor,
                  'imageAsset': i.product.imageAsset,
                  'oldPrice': i.product.oldPrice,
                  },
                  'color': i.color,
                  'length': i.length,
                  'quantity': i.quantity,
                })
            .toList(),
        'subtotal': o.subtotal,
        'shipping': o.shipping,
        'total': o.total,
        'status': o.status.name,
        'placedAt': o.placedAt.toIso8601String(),
        'paymentMethod': o.paymentMethod,
      };

  static Order? decode(Map<Object?, Object?> raw) {
    try {
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
              price: (pRaw['price'] as num).toDouble(),
              imageColor: (pRaw['imageColor'] as num).toInt(),
              imageAsset: pRaw['imageAsset'] as String?,
              oldPrice: pRaw['oldPrice'] == null
                  ? null
                  : (pRaw['oldPrice'] as num).toDouble(),
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
        subtotal: (raw['subtotal'] as num).toDouble(),
        shipping: (raw['shipping'] as num).toDouble(),
        total: (raw['total'] as num).toDouble(),
        status: status,
        placedAt: DateTime.parse(raw['placedAt'] as String),
        paymentMethod: raw['paymentMethod'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
