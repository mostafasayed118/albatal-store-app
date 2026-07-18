import 'package:equatable/equatable.dart';

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
  Address copyWith(
          {String? recipient,
          String? line,
          String? city,
          String? country,
          bool? isDefault}) =>
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
