/// Shipping address value object.
///
/// Lives in core/entities because it is referenced by both the presentation
/// layer (AddressForm widget) and the domain layer (CheckoutCubit state).
/// This avoids the layer violation of a Cubit importing a widget.
class Address {
  const Address({
    required this.name,
    required this.street,
    required this.city,
    required this.phone,
  });

  final String name, street, city, phone;

  @override
  String toString() => '$name, $street, $city';
}
