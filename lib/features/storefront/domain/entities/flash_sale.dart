import 'package:equatable/equatable.dart';

/// An active flash sale as read from the `flash_sales` table.
///
/// The repository maps raw RPC rows into this entity so the cubit and
/// pages switch on typed values instead of raw string keys; unknown or
/// malformed row shapes degrade to defaults (or are skipped) instead of
/// throwing at map time.
final class FlashSale extends Equatable {
  const FlashSale({
    required this.productId,
    this.discountPct = FlashSale.defaultDiscountPct,
    this.endsAt,
  });

  /// Fallback discount shown when a row carries no usable value — the
  /// same placeholder the storefront has always rendered.
  static const int defaultDiscountPct = 15;

  final String productId;
  final int discountPct;
  final DateTime? endsAt;

  @override
  List<Object?> get props => [productId, discountPct, endsAt];
}
