import 'package:equatable/equatable.dart';

/// A delivery address in the address book.
///
/// Invariants: [id] is stable identity (a missing id means the row is
/// unusable — callers skip it); at most one address in the book carries
/// [isDefault], enforced by the addresses feature, not by this value
/// object; [phone] is a validated Egyptian mobile number stored AS TYPED
/// (separators preserved — the courier dials what the customer sees, and
/// migration 065's `phone_digits` column already makes the admin
/// directory's digit search separator-proof, so no client-side reformat).
/// Wire shapes live in `core/data/address_codec.dart`, never here.
final class Address extends Equatable {
  const Address({
    required this.id,
    required this.recipient,
    required this.line,
    required this.city,
    required this.country,
    this.phone = '',
    this.isDefault = false,
  });

  final String id, recipient, line, city, country;

  /// The customer's contact number for fulfillment (courier calls before
  /// COD hand-off — UX-003). Defaults to `''` because addresses saved
  /// before the field shipped have no phone on file; `fromJson` degrades
  /// a missing/mistyped column to `''` the same way. Required at every
  /// UI entry point (both address forms validate it), so only legacy
  /// rows can carry `''`.
  final String phone;

  final bool isDefault;

  /// Whether a callable number is on file.
  ///
  /// The checkout uses this to gate order placement: an Egyptian COD order
  /// is undeliverable if the courier cannot call ahead (UX-003), and rows
  /// saved before the phone field shipped carry `''`. Kept on the entity so
  /// the card, the picker and the gate all agree on what "complete" means.
  bool get hasPhone => phone.trim().isNotEmpty;

  Address copyWith({
    String? recipient,
    String? line,
    String? city,
    String? country,
    String? phone,
    bool? isDefault,
  }) =>
      Address(
          id: id,
          recipient: recipient ?? this.recipient,
          line: line ?? this.line,
          city: city ?? this.city,
          country: country ?? this.country,
          phone: phone ?? this.phone,
          isDefault: isDefault ?? this.isDefault);

  @override
  List<Object?> get props =>
      [id, recipient, line, city, country, phone, isDefault];
}
