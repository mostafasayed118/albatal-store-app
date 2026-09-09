import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/address_codec.dart';
import '../../../core/entities/money.dart';
import '../../../core/entities/order.dart';
import '../../../core/entities/product.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/extensions/iterable_x.dart';
import '../../auth/domain/repositories/order_snapshot_port.dart';
import '../domain/repositories/cart_repository.dart';
import '../domain/repositories/idempotency_store.dart';
import 'product_mapper.dart';

/// SharedPreferences-backed persistence for the storefront feature.
///
/// Used as a delegate by [LocalCartRepository], [LocalWishlistRepository],
/// and [LocalOrdersRepository]. Returns raw values — error catching and
/// [Result] wrapping happens at the repository boundary (per Clean
/// Architecture §1: "mapping logic belongs in the data layer"; the repo
/// is the boundary). Previously this class swallowed all errors and
/// returned empty data, which hid persistence failures from the
/// presentation layer.
final class LocalStorefrontPersistence
    implements IdempotencyStore, OrderSnapshotPort {
  LocalStorefrontPersistence(this._preferences);

  static const _cartKey = 'storefront_cart_lines_v1';
  static const _wishlistKey = 'storefront_wishlist_ids_v1';
  static const _ordersKey = 'storefront_orders_v1';

  /// Persisted checkout idempotency key + write timestamp (see
  /// [IdempotencyStore]). Survives app restarts (crash mid-checkout)
  /// with a 24h TTL enforced by the checkout use-case so the server
  /// can return the original pending order instead of a duplicate.
  static const _idempotencyKeyStorage = 'checkout_idempotency_key';
  static const _idempotencyTsStorage = 'checkout_idempotency_key_ts';
  final SharedPreferences _preferences;

  Future<List<CartItem>> readCart(ProductLookup productForId) async {
    final raw = _preferences.getString(_cartKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((line) {
          final product = productForId(safeString(line, 'productId'));
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

  /// Deletes the local order-history snapshot.
  ///
  /// Raw-value semantics like the other writers here; used by the auth
  /// wipe so a signed-out or deleted device keeps no order PII (audit
  /// S9). Server orders are unaffected — this only clears the legacy
  /// on-device snapshot.
  Future<void> clearOrders() async {
    await _preferences.remove(_ordersKey);
  }

  @override
  Future<void> clearOrderSnapshots() => clearOrders();

  @override
  String? loadKey() => _preferences.getString(_idempotencyKeyStorage);

  @override
  int? loadTimestampMs() => _preferences.getInt(_idempotencyTsStorage);

  @override
  Future<void> saveKey(String key, int timestampMs) async {
    await _preferences.setString(_idempotencyKeyStorage, key);
    await _preferences.setInt(_idempotencyTsStorage, timestampMs);
  }

  @override
  Future<void> clear() async {
    // Dispatch both removals synchronously (no await between them): the
    // legacy cubit fired both `prefs.remove` calls back-to-back, and
    // fire-and-forget callers (resetForNewAttempt / markSuccess) plus
    // their tests observe key and timestamp gone immediately.
    final clearKey = _preferences.remove(_idempotencyKeyStorage);
    final clearTs = _preferences.remove(_idempotencyTsStorage);
    await Future.wait([clearKey, clearTs]);
  }
}

/// Serializes [Order] to/from JSON for the SharedPreferences persistence layer.
///
/// Orders snapshot the full [Product] (not just an ID) so a historical order
/// stays correct if the catalog later changes price or removes a product. This
/// mirrors a paper receipt: line items are frozen at confirmation time.
extension OrderCodec on Order {
  static Map<String, Object?> encode(Order o) => {
        'id': o.id,
        'items': o.items
            .map((i) => {
                  'product': ProductCodec.encode(i.product),
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
        if (o.address != null) 'address': AddressCodec.toJson(o.address!),
      };

  static Order? decode(Map<Object?, Object?> raw) {
    final itemsRaw = raw['items'];
    if (itemsRaw is! List) return null;
    final items = itemsRaw
        .whereType<Map>()
        .map((line) {
          final pRaw = line['product'];
          if (pRaw is! Map) return null;
          final product = ProductCodec.decode(pRaw);
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
          ? AddressCodec.fromOrderJson(safeMap(raw['address']))
          : null,
    );
  }
}
