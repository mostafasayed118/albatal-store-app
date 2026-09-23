import '../entities/address.dart';
import '../utils/safe_parse.dart';

/// Single owner of every hand-built address map in the app.
///
/// The three call sites share one [Address] class (the addresses feature
/// re-exports the core entity) but two persisted shapes, so this codec
/// exposes one method per legacy builder, copied verbatim:
/// - [toJson]/[fromJson]: the 7-key address-book shape
///   (`local_address_repository`; the 6 pre-phone keys + `phone`).
/// - [fromOrderJson]: the order-snapshot decode — same keys and same
///   tolerant fallbacks as the address-book shape, so it delegates to
///   [fromJson] (legacy `OrderCodec._decodeAddress` behavior).
/// - [toSnapshotJson]: the 6-key server snapshot sent as `p_address`
///   by `checkout_service` (the 5 legacy keys + `phone`; encode-only,
///   the server never sends one back). The RPC enforces only
///   `recipient`/`line`/`city` and stores the map verbatim into
///   `orders.address_snapshot` (migrations 013→066), so the additive
///   key is contract-safe — that server-side review is what unblocked
///   UX-003's "needs backend ack" dependency.
abstract final class AddressCodec {
  static Map<String, dynamic> toJson(Address address) => {
        'id': address.id,
        'recipient': address.recipient,
        'line': address.line,
        'city': address.city,
        'country': address.country,
        'phone': address.phone,
        'isDefault': address.isDefault,
      };

  /// Decodes the address-book shape. Total: missing/mistyped values
  /// degrade to `''`/`false` instead of throwing, so one tampered cache
  /// entry can never crash the read — callers skip empty-`id` results
  /// (see `LocalAddressRepository.read`). A missing `phone` (every row
  /// persisted before the field shipped) degrades to `''` — "no phone
  /// on file", not an error.
  static Address fromJson(Map<String, dynamic> json) => Address(
        id: safeString(json, 'id'),
        recipient: safeString(json, 'recipient'),
        line: safeString(json, 'line'),
        city: safeString(json, 'city'),
        country: safeString(json, 'country'),
        phone: safeString(json, 'phone'),
        isDefault: safeBool(json, 'isDefault'),
      );

  /// Decodes the order-snapshot shape. The snapshot carries the same keys
  /// as the address-book shape (tolerant `country` fallback included), so
  /// this delegates to [fromJson] — one decode, one set of fallbacks.
  static Address fromOrderJson(Map<String, dynamic> json) => fromJson(json);

  static Map<String, dynamic> toSnapshotJson(Address address) => {
        'id': address.id,
        'recipient': address.recipient,
        'line': address.line,
        'city': address.city,
        'country': address.country,
        'phone': address.phone,
      };
}
