import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/entities/product.dart';

typedef ProductLookup = Product? Function(String id);

abstract interface class StorefrontPersistence {
  Future<List<CartItem>> readCart(ProductLookup productForId);
  Future<Set<String>> readWishlist();
  Future<void> writeCart(List<CartItem> items);
  Future<void> writeWishlist(Set<String> ids);
}

final class LocalStorefrontPersistence implements StorefrontPersistence {
  LocalStorefrontPersistence(this._preferences);

  static const _cartKey = 'storefront_cart_lines_v1';
  static const _wishlistKey = 'storefront_wishlist_ids_v1';
  final SharedPreferences _preferences;

  @override
  Future<List<CartItem>> readCart(ProductLookup productForId) async {
    try {
      final raw = _preferences.getString(_cartKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<Map>().map((line) {
        final product = productForId(line['productId'] as String? ?? '');
        final color = line['color'];
        final length = line['length'];
        final quantity = line['quantity'];
        if (product == null || color is! String || length is! String || quantity is! num) return null;
        return CartItem(
          product: product,
          color: color,
          length: length,
          quantity: quantity.toInt().clamp(1, 99).toInt(),
        );
      }).whereType<CartItem>().toList();
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
  Future<void> writeWishlist(Set<String> ids) => _write(_wishlistKey, ids.toList()..sort());

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
}
