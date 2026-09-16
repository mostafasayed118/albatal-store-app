import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';

/// Cut-length and wholesale pricing (Wave C).
///
/// Domain-level, owner-tunable constants: change the tier table here to
/// adjust the B2B discount ladder without touching widget or cubit code.
/// All money math stays in [Money] minor units — no `double` arithmetic
/// ever multiplies prices.

/// Hard upper bound for a single cut-length line (meters). The details
/// cubit clamps to this; keep in sync with the server-side cap.
const double kCutLengthMaxMeters = 50.0;

/// Metering grid: cut lengths snap to steps of this size.
const double kCutLengthStepMeters = 0.5;

/// Wholesale discount ladder for cut-length orders. The FIRST matching
/// (highest) tier whose threshold the ordered meters satisfy wins.
/// Ordered descending by threshold.
const List<({double minMeters, int discountPercent})> kWholesaleTiers = [
  (minMeters: 25.0, discountPercent: 10),
  (minMeters: 10.0, discountPercent: 5),
];

/// The discount percentage that applies at [meters] of cut length,
/// 0 when no tier is reached.
int tierDiscountPercent(double meters) {
  for (final tier in kWholesaleTiers) {
    if (meters >= tier.minMeters) return tier.discountPercent;
  }
  return 0;
}

/// Per-meter price after the wholesale tier discount, in minor units
/// (integer truncation — the client never rounds the customer's price
/// up by a fraction).
Money tieredPerMeterPrice(Money basePerMeter, double meters) {
  final pct = tierDiscountPercent(meters);
  if (pct == 0) return basePerMeter;
  return Money(basePerMeter.minorUnits * (100 - pct) ~/ 100);
}

/// Line total for a metered cut: per-meter price × meters × quantity,
/// computed in minor units. [meters] sits on the 0.5 m grid, so
/// `minorUnits × meters` is at most a half-minor-unit fraction away
/// from an integer, and rounding lands on exact minor units.
///
/// NOTE: the result is whole *minor* units, not whole major units —
/// 39950 × 2.5 = 99875, i.e. 998.75 EGP. Rendering it must therefore
/// keep the piasters ([Money.format] does); truncating to whole pounds
/// would display less than the `line_total` submitted at checkout.
Money meteredLineTotal(Money perMeter, double meters, {int quantity = 1}) =>
    Money((perMeter.minorUnits * meters).round() * quantity);

/// Cut-length/sample pricing for a cart line.
///
/// Lives in the feature domain (not on [CartItem] itself) so the core
/// entity keeps its zero-bloat fixed-size contract while the storefront
/// layers the metered and sample semantics on top.
extension CartItemPricing on CartItem {
  /// Ordered cut length in meters, or null for fixed-size lines.
  /// The variant-length string ('2.5') already carries the meters —
  /// same contract the checkout RPC reads.
  double? get cutMeters =>
      product.sellByLength ? double.tryParse(length) : null;

  /// Per-meter price after the wholesale tier for this line's meters,
  /// or null for fixed-size / sample lines.
  Money? get effectivePerMeterPrice {
    final meters = cutMeters;
    if (meters == null) return null;
    return tieredPerMeterPrice(product.price, meters);
  }

  /// Client-side estimate of the line total used for cart/checkout
  /// display: zero for sample lines (server prices them), metered
  /// tier math for sell-by-length lines, fixed math otherwise. The
  /// server totals remain authoritative.
  Money get effectiveLineTotal {
    if (sample) return Money.zero;
    final meters = cutMeters;
    if (meters == null) return lineTotal;
    return meteredLineTotal(tieredPerMeterPrice(product.price, meters), meters,
        quantity: quantity);
  }
}
