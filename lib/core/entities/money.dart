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

  /// Parses a major-unit amount into exact integer minor units.
  ///
  /// Returns null for malformed, negative, exponent, or sub-piastre input so
  /// an editor can reject a value instead of silently rounding it.
  static Money? tryParseMajor(String source) {
    final value = source.trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final major = int.parse(parts.first);
    final fractional =
        parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
    return Money(major * 100 + fractional);
  }

  /// Zero value for empty carts, free shipping, etc.
  static const zero = Money(0);

  /// Integer minor units (cents). 1290 EGP == `Money(129000)`.
  final int minorUnits;

  /// Major units as a double — for display only, never for arithmetic.
  double get majorUnits => minorUnits / 100;

  /// Formats as a compact currency string for UI display:
  /// `Money.egp(1290).format()` → `"1290 EGP"`.
  ///
  /// The default symbol is the ISO 4217 code for the Egyptian pound.
  /// It used to be `'EGY'`, which is not a currency code at all (that is
  /// the ISO 3166 country code) — audit UX-019. `format()` stays
  /// deterministic and locale-agnostic on purpose: it is the domain-level
  /// formatter used by generated documents, the admin console, and
  /// non-UI composition. Shopper-facing surfaces go through
  /// `moneyText()` in `shared/l10n/money_copy.dart`, which localizes the
  /// digits, the grouping, the symbol and its placement.
  ///
  /// Whole amounts carry no decimals (the app's existing UI convention),
  /// but fractional piasters are KEPT rather than truncated:
  /// `Money(99875).format()` → `"998.75 EGP"`. This matters because
  /// cut-length metered lines routinely land on a fractional major unit
  /// ([meteredLineTotal] rounds to whole minor units, not whole pounds),
  /// so truncating would show the customer a total that disagrees with
  /// the amount recorded on the order.
  String format({String symbol = 'EGP'}) {
    final minor = minorUnits % 100;
    if (minor == 0) return '${minorUnits ~/ 100} $symbol';
    return '${minorUnits ~/ 100}.${minor.toString().padLeft(2, '0')} $symbol';
  }

  /// Formats with exactly two decimals, for documents (invoices, admin
  /// tables) where the exact amount must always be legible:
  /// `Money.egp(1290).formatExact()` → `"1290.00 EGP"`.
  ///
  /// Pass an empty [symbol] where a column header already names the
  /// currency: `Money(99875).formatExact(symbol: '')` → `"998.75"`.
  String formatExact({String symbol = 'EGP'}) {
    final minor = (minorUnits % 100).toString().padLeft(2, '0');
    final amount = '${minorUnits ~/ 100}.$minor';
    return symbol.isEmpty ? amount : '$amount $symbol';
  }

  /// Whole-major-units label without decimals (the admin surfaces render
  /// 1890, not 1890.0); keeps two decimals when the value is fractional
  /// (`12.5` → `"12.50"`).
  ///
  /// NOTE: this `double` entry exists for non-money quantities (e.g. meter
  /// cut lengths in `pricing_tier_table.dart`). Money callers must prefer
  /// [wholeEgpLabelFromMinor] so a `double` can never round-trip back into
  /// the minor-unit discipline this file enforces.
  static String wholeEgpLabel(double majorUnits) {
    final s = majorUnits.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  /// Canonical money label from integer minor units — no `double` in the
  /// path. `Money(129000).label()` → `"1290"`, `Money(99875).label()` →
  /// `"998.75"`. Prefer this over [wholeEgpLabel] for prices.
  String label() {
    final minor = minorUnits % 100;
    if (minor == 0) return '${minorUnits ~/ 100}';
    return '${minorUnits ~/ 100}.${minor.toString().padLeft(2, '0')}';
  }

  /// Static twin of [label] for call sites holding raw minor units.
  static String wholeEgpLabelFromMinor(int minorUnits) =>
      Money(minorUnits).label();

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
