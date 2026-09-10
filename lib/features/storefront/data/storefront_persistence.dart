import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/address_codec.dart';
import '../../../core/entities/money.dart';
import '../../../core/entities/order.dart';
import '../../../core/entities/product.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/extensions/iterable_x.dart';
import '../../../shared/services/logger.dart';
import '../../../shared/services/secure_store.dart';
import '../../auth/domain/repositories/order_snapshot_port.dart';
import '../domain/repositories/cart_repository.dart';
import '../domain/repositories/idempotency_store.dart';
import 'product_mapper.dart';

/// SharedPreferences-backed persistence for the storefront feature.
///
/// Cart lines, wishlist ids, and the checkout idempotency key stay in
/// plain prefs (non-sensitive). The order-history snapshot carries full
/// shipping addresses, so it lives in the encrypted [SecureStore]
/// instead — see [_readOrdersWithMigration]. Returns raw values — error
/// catching and [Result] wrapping happens at the repository boundary
/// (per Clean Architecture §1: "mapping logic belongs in the data
/// layer"; the repo is the boundary). Previously this class swallowed
/// all errors and returned empty data, which hid persistence failures
/// from the presentation layer.
final class LocalStorefrontPersistence
    implements IdempotencyStore, OrderSnapshotPort {
  LocalStorefrontPersistence(this._preferences, {SecureStore? secureStore})
      : _secureStore = secureStore ?? FlutterSecureStore();

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

  /// Encrypted at-rest store for the order-history snapshot (PII: full
  /// shipping addresses + item history). The prefs handle still owns
  /// cart/wishlist/idempotency plus the one-time legacy migration and
  /// legacy-key wipe.
  final SecureStore _secureStore;

  Future<List<CartItem>> readCart(ProductLookup productForId) async {
    final raw = _preferences.getString(_cartKey);
    if (raw == null) return const [];
    // Fail-soft on tampered cache: corrupt JSON yields an empty cart
    // (logged), never a throw into the cubit.
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      Log.w('Cart cache is corrupt; ignoring: $e');
      return const [];
    }
    if (decoded is! List) {
      Log.w('Cart cache has unexpected shape; ignoring.');
      return const [];
    }
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
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      Log.w('Wishlist cache is corrupt; ignoring: $e');
      return <String>{};
    }
    if (decoded is! List) {
      Log.w('Wishlist cache has unexpected shape; ignoring.');
      return <String>{};
    }
    return decoded.whereType<String>().toSet();
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
    final raw = await _readOrdersWithMigration();
    if (raw == null) return const [];
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      Log.w('Order snapshot cache is corrupt; ignoring: $e');
      return const [];
    }
    if (decoded is! List) {
      Log.w('Order snapshot cache has unexpected shape; ignoring.');
      return const [];
    }
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
  /// S9). Wipes the encrypted entry AND the legacy cleartext prefs key
  /// so a pre-migration snapshot cannot survive the wipe. Server orders
  /// are unaffected — this only clears the legacy on-device snapshot.
  Future<void> clearOrders() async {
    await _secureStore.delete(_ordersKey);
    await _preferences.remove(_ordersKey);
  }

  /// Reads the encrypted order snapshot, migrating a cleartext legacy
  /// prefs entry once (write-to-secure then remove prefs) so upgrades
  /// keep the snapshot without leaving PII in cleartext.
  Future<String?> _readOrdersWithMigration() async {
    final secured = await _secureStore.read(_ordersKey);
    if (secured != null) return secured;
    final legacy = _preferences.getString(_ordersKey);
    if (legacy == null) return null;
    await _secureStore.write(_ordersKey, legacy);
    await _preferences.remove(_ordersKey);
    return legacy;
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

/// Serializes [Order] to/from JSON for the encrypted snapshot store.
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

  /// Total: never throws — any malformed entry (mistyped fields,
  /// unparseable timestamp, corrupt nested product) logs and yields
  /// `null` so the caller skips that order instead of failing the read.
  static Order? decode(Map<Object?, Object?> raw) {
    try {
      final itemsRaw = raw['items'];
      if (itemsRaw is! List) {
        Log.w('Order snapshot entry has no items; skipping.');
        return null;
      }
      final items = itemsRaw
          .whereType<Map>()
          .map((line) {
            // Per-line total: a corrupt product snapshot skips that line,
            // never the whole order (or the whole read).
            try {
              final pRaw = line['product'];
              if (pRaw is! Map) return null;
              final product = ProductCodec.decode(pRaw);
              // Corrupt product snapshot skips that line, never the order.
              if (product == null) return null;
              final color = safeString(line, 'color');
              final length = safeString(line, 'length');
              if (color.isEmpty || length.isEmpty) return null;
              return CartItem(
                product: product,
                color: color,
                length: length,
                quantity: safeInt(line, 'quantity', fallback: 1).clamp(1, 99),
              );
            } catch (e) {
              Log.w('Order snapshot line is corrupt; skipping: $e');
              return null;
            }
          })
          .whereType<CartItem>()
          .toList();
      final status =
          OrderStatus.values.where((s) => s.name == raw['status']).firstOrNull;
      if (status == null) {
        Log.w('Order snapshot entry has unknown status; skipping.');
        return null;
      }
      final id = safeString(raw, 'id');
      if (id.isEmpty) {
        Log.w('Order snapshot entry has missing id; skipping.');
        return null;
      }
      final placedAt = DateTime.tryParse(safeString(raw, 'placedAt'));
      if (placedAt == null) {
        Log.w('Order snapshot entry has invalid placedAt; skipping.');
        return null;
      }
      final addressMap = safeMap(raw['address']);
      return Order(
        id: id,
        items: items,
        subtotal: Money(safeInt(raw, 'subtotal')),
        shipping: Money(safeInt(raw, 'shipping')),
        total: Money(safeInt(raw, 'total')),
        status: status,
        placedAt: placedAt,
        paymentMethod: safeString(raw, 'paymentMethod'),
        address:
            addressMap.isEmpty ? null : AddressCodec.fromOrderJson(addressMap),
      );
    } catch (e) {
      Log.w('Order snapshot entry is corrupt; skipping: $e');
      return null;
    }
  }
}
