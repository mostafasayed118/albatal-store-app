import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

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

  /// Formats as a currency string: `Money.egp(1290).format()` → `"1290 EGP"`.
  ///
  /// Uses whole major units (no decimals) to match the existing UI convention.
  /// When [locale] is provided, digit grouping follows that locale while the
  /// amount stays identical for business logic. Pass a localized [symbol]
  /// (e.g. from `AppLocalizations.currencyCode`) for Arabic display.
  String format({String symbol = 'EGP', String? locale}) {
    final major = minorUnits / 100;
    final number = locale == null
        ? major.toStringAsFixed(0)
        : NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 0)
            .format(major);
    return '$number $symbol';
  }

  // ─── Arithmetic ────────────────────────────────────────────

  Money operator +(Money other) => Money(minorUnits + other.minorUnits);
  Money operator -(Money other) => Money(minorUnits - other.minorUnits);
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
