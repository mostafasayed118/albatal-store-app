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
  /// Truncates (integer division) — fractional minor units never round up.
  String format({String symbol = 'EGY'}) => '${minorUnits ~/ 100} $symbol';

  // ─── Canonical display helpers (audit 2026-09: four screens had
  // hand-rolled minor-units→EGP formatting — now single-sourced here) ──

  /// Two-decimal major-units string: `const Money(189000).majorLabel()` →
  /// `"1890.00"`. Display only — money math stays in integer minor units.
  String majorLabel() => (minorUnits / 100).toStringAsFixed(2);

  /// Canonical minor-units → EGP display label:
  /// `const Money(189000).egpLabel()` → `"EGP 1890.00"`.
  String egpLabel() => 'EGP ${majorLabel()}';

  /// Whole-major-units label without decimals (the admin surfaces render
  /// 1890, not 1890.0); keeps two decimals when the value is fractional
  /// (`12.5` → `"12.50"`).
  static String wholeEgpLabel(double majorUnits) {
    final s = majorUnits.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

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
