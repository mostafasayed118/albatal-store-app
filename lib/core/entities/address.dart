import 'package:equatable/equatable.dart';

/// A delivery address in the address book.
///
/// Invariants: [id] is stable identity (a missing id means the row is
/// unusable — callers skip it); at most one address in the book carries
/// [isDefault], enforced by the addresses feature, not by this value
/// object. Wire shapes live in `core/data/address_codec.dart`, never
/// here.
final class Address extends Equatable {
  const Address(
      {required this.id,
      required this.recipient,
      required this.line,
      required this.city,
      required this.country,
      this.isDefault = false});

  final String id, recipient, line, city, country;
  final bool isDefault;

  Address copyWith({
    String? recipient,
    String? line,
    String? city,
    String? country,
    bool? isDefault,
  }) =>
      Address(
          id: id,
          recipient: recipient ?? this.recipient,
          line: line ?? this.line,
          city: city ?? this.city,
          country: country ?? this.country,
          isDefault: isDefault ?? this.isDefault);

  @override
  List<Object?> get props => [id, recipient, line, city, country, isDefault];
}
