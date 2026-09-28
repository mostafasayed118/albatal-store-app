import '../../../../core/entities/product.dart';

/// Fit recommendation (Batch 3 #2 tailor): "how much fabric do I need?"
///
/// Client-only, owner-tunable yardage table — no server round-trip, no
/// migration. Base lengths assume the reference body (175 cm) on
/// standard-width fabric (150 cm); [recommendedMeters] scales for height
/// and pads narrow rolls, then snaps UP to the 0.5 m metering grid so
/// the result feeds [setCutLength]-style metered selection directly.
/// Fixed-size products resolve through [nearestFixedSize] instead.
///
/// All numbers are estimates for cutting guidance, never prices.

/// Reference body height (cm) the base table is cut for.
const double kFitReferenceHeightCm = 175.0;

/// Reference fabric width (cm) the base table assumes.
const int kFitReferenceWidthCm = 150;

/// Extra length (m) added when the roll is narrower than the reference
/// width — narrow fabric fits fewer pattern pieces side by side.
const double kFitNarrowWidthPadMeters = 0.5;

/// Shopper height stepper bounds (cm).
const double kFitMinHeightCm = 150.0;
const double kFitMaxHeightCm = 210.0;
const double kFitHeightStepCm = 5.0;

/// Garments the recommender covers, with base meters at the reference
/// body on reference-width fabric. Ordered by cloth needed.
enum FitGarment {
  trousers(1.5),
  shirt(2.0),
  abaya(3.0),
  thobe(3.5);

  const FitGarment(this.baseMeters);
  final double baseMeters;
}

/// Recommended cut length (m) for [garment] on a [heightCm] body and a
/// [widthCm] roll (null = unknown width, assumed standard).
/// Height scales the base within 0.9–1.15× so extreme inputs cannot
/// produce absurd cuts; the result snaps UP to the 0.5 m grid.
double recommendedMeters(
  FitGarment garment, {
  double heightCm = kFitReferenceHeightCm,
  int? widthCm,
}) {
  final height = heightCm.clamp(kFitMinHeightCm, kFitMaxHeightCm);
  final scale = (height / kFitReferenceHeightCm).clamp(0.9, 1.15);
  var meters = garment.baseMeters * scale;
  if (widthCm != null && widthCm < kFitReferenceWidthCm) {
    meters += kFitNarrowWidthPadMeters;
  }
  // Snap UP (never down — short-changing a cut ruins the garment).
  return (meters * 2).ceilToDouble() / 2;
}

/// Whether [widthCm] triggers the narrow-roll pad.
bool isNarrowRoll(int? widthCm) =>
    widthCm != null && widthCm < kFitReferenceWidthCm;

/// Nearest fixed size at or above [meters], else the largest size.
/// Only numeric sizes participate ('1m' counts as 1.0); an empty or
/// non-numeric size list yields null so callers can hide Apply.
String? nearestFixedSize(List<String> sizes, double meters) {
  final numeric = <double, String>{};
  for (final size in sizes) {
    final value = double.tryParse(size.replaceAll('m', ''));
    if (value != null) numeric[value] = size;
  }
  if (numeric.isEmpty) return null;
  final atOrAbove =
      numeric.keys.where((value) => value >= meters).toList()..sort();
  if (atOrAbove.isNotEmpty) return numeric[atOrAbove.first];
  final all = numeric.keys.toList()..sort();
  return numeric[all.last];
}

/// Apply-target for a recommendation: a metered cut for sell-by-length
/// products, the nearest fixed size otherwise (null when the product
/// has no usable size).
String? fitApplyLength(Product product, double meters) {
  if (product.sellByLength) return meters.toStringAsFixed(1);
  return nearestFixedSize(product.sizes, meters);
}
