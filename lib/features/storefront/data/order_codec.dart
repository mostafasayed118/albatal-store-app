import '../../../core/data/address_codec.dart';
import '../../../core/entities/money.dart';
import '../../../core/entities/order.dart';
import '../../../core/entities/product.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/extensions/iterable_x.dart';
import '../../../shared/services/logger.dart';
import 'product_mapper.dart';

/// Serializes [Order] to/from JSON for the encrypted snapshot store.
///
/// Orders snapshot the full [Product] (not just an ID) so a historical order
/// stays correct if the catalog later changes price or removes a product. This
/// mirrors a paper receipt: line items are frozen at confirmation time.
///
/// Extracted from `storefront_persistence.dart`; re-exported there so the
/// codec's import surface is unchanged.
extension OrderCodec on Order {
  static Map<String, Object?> encode(Order o) => {
        'id': o.id,
        'items': o.items
            .map((i) => {
                  'product': ProductCodec.encode(i.product),
                  'color': i.color,
                  'length': i.length,
                  'quantity': i.quantity,
                  if (i.sample) 'sample': true,
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
                sample: safeBool(line, 'sample'),
              );
            } catch (e) {
              Log.w('Order snapshot line is corrupt; skipping.', error: e);
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
      Log.w('Order snapshot entry is corrupt; skipping.', error: e);
      return null;
    }
  }
}
