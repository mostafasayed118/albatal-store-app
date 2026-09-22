import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/entities/order.dart';
import '../../../core/entities/product.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../../../shared/services/secure_store.dart';
import '../../auth/domain/repositories/order_snapshot_port.dart';
import '../domain/repositories/cart_repository.dart';
import '../domain/repositories/idempotency_store.dart';
import 'order_codec.dart';

export 'order_codec.dart';

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
      // Fail-soft: corrupt cart degrades to empty (logged without
      // interpolating the raw payload; audit 2026-09-14 P0-5).
      Log.w('Cart cache is corrupt; ignoring.', error: e);
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
            sample: safeBool(line, 'sample'),
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
      Log.w('Wishlist cache is corrupt; ignoring.', error: e);
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
                if (item.sample) 'sample': true,
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
      Log.w('Order snapshot cache is corrupt; ignoring.', error: e);
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
