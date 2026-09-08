import '../entities/address.dart';
import '../utils/safe_parse.dart';

/// Single owner of every hand-built address map in the app.
///
/// The three call sites share one [Address] class (the addresses feature
/// re-exports the core entity) but two persisted shapes, so this codec
/// exposes one method per legacy builder, copied verbatim:
/// - [toJson]/[fromJson]: the 6-key address-book shape
///   (`local_address_repository`).
/// - [fromOrderJson]: the order-snapshot decode, which degrades a
///   missing/mistyped `country` to `''` via [safeString] instead of
///   throwing (legacy `OrderCodec._decodeAddress` behavior).
/// - [toSnapshotJson]: the 5-key server snapshot sent as `p_address`
///   by `checkout_cubit` (encode-only; the server never sends one back).
abstract final class AddressCodec {
  static Map<String, dynamic> toJson(Address address) => {
        'id': address.id,
        'recipient': address.recipient,
        'line': address.line,
        'city': address.city,
        'country': address.country,
        'isDefault': address.isDefault,
      };

  static Address fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String,
        recipient: json['recipient'] as String,
        line: json['line'] as String,
        city: json['city'] as String,
        country: json['country'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  static Address fromOrderJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String,
        recipient: json['recipient'] as String,
        line: json['line'] as String,
        city: json['city'] as String,
        country: safeString(json, 'country'),
        isDefault: safeBool(json, 'isDefault'),
      );

  static Map<String, dynamic> toSnapshotJson(Address address) => {
        'id': address.id,
        'recipient': address.recipient,
        'line': address.line,
        'city': address.city,
        'country': address.country,
      };
}
