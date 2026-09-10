import 'package:equatable/equatable.dart';

/// An immutable monetary value stored as integer minor units (e.g. cents).
///
/// Storing money as integer minor units — never `double` — avoids the
/// rounding errors that plague floating-point arithmetic. The database
/// schema already follows this convention (`base_price INTEGER` is cents);
/// this type carries that discipline through the domain and presentation
/// layers without leaking `/ 100` or `* 100` conversions across the
/// codebase.
///
/// Conventions:
/// - `Money(129000)` == 1290.00 EGP (canonical form, used for DB rows).
/// - `Money.egp(1290)` == 1290.00 EGP (readable form, used in mock data).
/// - Both are equal: `Money(129000) == Money.egp(1290)`.
final class Money extends Equatable {
  const Money(this.minorUnits) : assert(minorUnits >= 0);

  /// Constructs [Money] from major currency units (e.g. whole EGP).
  /// `const Money.egp(1290)` represents 1290.00 EGP.
  const Money.egp(int majorUnits)
      : minorUnits = majorUnits * 100,
        assert(majorUnits >= 0);

  /// Zero value for empty carts, free shipping, etc.
  static const zero = Money(0);

  /// Integer minor units (cents). 1290 EGP == `Money(129000)`.
  final int minorUnits;

  /// Major units as a double — for display only, never for arithmetic.
  double get majorUnits => minorUnits / 100;

  /// Formats as a currency string: `Money.egp(1290).format()` → `"1290 EGY"`.
  /// Uses whole major units (no decimals) to match the existing UI convention.
  String format({String symbol = 'EGY'}) =>
      '${(minorUnits / 100).toStringAsFixed(0)} $symbol';

  // ─── Arithmetic ────────────────────────────────────────────

  Money operator +(Money other) => Money(minorUnits + other.minorUnits);

  /// Requires `other.minorUnits <= minorUnits` (asserts in debug via the
  /// [Money] constructor; use [subtractClamped] for discount math that may
  /// exceed the total).
  Money operator -(Money other) => Money(minorUnits - other.minorUnits);

  /// Clamped subtraction for discount math; floors at zero instead of
  /// asserting. Prefer this when the discount may exceed the total.
  Money subtractClamped(Money other) => Money(
      minorUnits - other.minorUnits < 0 ? 0 : minorUnits - other.minorUnits);
  Money operator *(int factor) => Money(minorUnits * factor);

  // ─── Comparison ────────────────────────────────────────────

  bool operator >=(Money other) => minorUnits >= other.minorUnits;
  bool operator <=(Money other) => minorUnits <= other.minorUnits;
  bool operator >(Money other) => minorUnits > other.minorUnits;
  bool operator <(Money other) => minorUnits < other.minorUnits;

  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  List<Object?> get props => [minorUnits];
}
