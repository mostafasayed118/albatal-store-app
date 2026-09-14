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

  /// Formats as a currency string: `Money.egp(1290).format()` → `"1290 EGY"`,
  /// `Money(129050).format()` → `"1290.50 EGY"`. Piasters render only when
  /// present, so whole amounts keep the established whole-EGY style while
  /// fractional values are displayed instead of truncated by integer
  /// division (audit 2026-09-14: `129050` must not read as "1290 EGY").
  /// Pass an empty [symbol] for the bare major-unit number.
  String format({String symbol = 'EGY'}) {
    final major = minorUnits ~/ 100;
    final piasters = minorUnits % 100;
    final value = piasters == 0
        ? '$major'
        : '$major.${piasters.toString().padLeft(2, '0')}';
    return symbol.isEmpty ? value : '$value $symbol';
  }

  /// Parses user-entered major-unit decimal text (`"1290"`, `"1290.5"`,
  /// `"1290.50"`) into [Money]. Returns null for blank, malformed, or
  /// negative input, and rejects more than two decimal places — an
  /// unrepresentable piaster amount must not be silently rounded.
  ///
  /// Audit 2026-09-14: the admin price form collects EGP text while the
  /// DB stores INTEGER minor units, so this is the single `* 100`
  /// conversion point (string-exact, no float arithmetic).
  static Money? tryParseMajor(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final parts = text.split('.');
    if (parts.length > 2) return null;
    final major = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (major == null || major < 0) return null;
    var minor = major * 100;
    if (parts.length == 2) {
      final frac = parts[1];
      if (frac.length > 2) return null;
      final piasters = frac.isEmpty ? 0 : int.tryParse(frac);
      if (piasters == null) return null;
      minor += frac.length == 1 ? piasters * 10 : piasters;
    }
    return Money(minor);
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
