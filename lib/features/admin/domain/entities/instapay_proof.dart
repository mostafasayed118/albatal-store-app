import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/utils/safe_parse.dart';

/// Display length of the short order handle shown in review rows.
const instapayShortOrderIdLength = 8;

/// First [instapayShortOrderIdLength] characters of [id], unchanged when the
/// id is already short (deep links and fixtures carry ids of both shapes).
String shortInstapayOrderId(String id) =>
    id.length <= instapayShortOrderIdLength
        ? id
        : id.substring(0, instapayShortOrderIdLength);

/// One pending InstaPay transfer proof awaiting admin review.
///
/// Mirrors one row of `public.admin_list_instapay_proofs()` (migration 082):
/// the proof itself plus the order total and customer name the admin needs
/// to decide, joined server-side because `payments` is owner-only under RLS.
final class InstapayProof extends Equatable {
  const InstapayProof({
    required this.proofId,
    required this.paymentId,
    required this.orderId,
    required this.total,
    required this.customerName,
    required this.storagePath,
    required this.createdAt,
    this.reference,
  });

  /// Maps one RPC row, or null when the row cannot be reviewed.
  ///
  /// A row without a proof id cannot be approved/rejected, and a row without
  /// an order id, total or timestamp would render a lying card (zero total,
  /// epoch date). Those are skipped instead of failing the whole queue —
  /// the same fail-soft contract as the pending-review and customer reads.
  /// [Money] forbids negative minor units, so a negative total is malformed.
  static InstapayProof? tryFromRow(Map<String, dynamic> row) {
    final proofId = safeString(row, 'proof_id');
    final orderId = safeString(row, 'order_id');
    final totalMinor = optInt(row, 'order_total');
    final createdAt = safeDateTime(row, 'created_at');
    if (proofId.isEmpty ||
        orderId.isEmpty ||
        totalMinor == null ||
        totalMinor < 0 ||
        createdAt == null) {
      return null;
    }
    final customerName = safeString(row, 'customer_name').trim();
    final reference = optString(row, 'reference')?.trim();
    return InstapayProof(
      proofId: proofId,
      paymentId: safeString(row, 'payment_id'),
      orderId: orderId,
      total: Money(totalMinor),
      // The queue must always name a payer; a blank profile name falls back
      // to the order handle the admin can recognise from the orders screen.
      customerName:
          customerName.isEmpty ? shortInstapayOrderId(orderId) : customerName,
      reference: reference == null || reference.isEmpty ? null : reference,
      storagePath: safeString(row, 'storage_path').trim(),
      createdAt: createdAt,
    );
  }

  /// `instapay_proofs.id` — the value the review function acts on.
  final String proofId;

  /// `payments.id` behind the proof (returned by the review call).
  final String paymentId;

  /// `orders.id` the payment belongs to.
  final String orderId;

  /// Order total in integer minor units, exactly as the order recorded it.
  final Money total;

  /// Payer name; never empty (falls back to the short order id).
  final String customerName;

  /// Admin-entered transfer reference, when the customer supplied one.
  final String? reference;

  /// Path inside the private `instapay-proofs` bucket; empty when the
  /// customer submitted the proof without a stored file.
  final String storagePath;

  /// When the proof was submitted (server timestamp).
  final DateTime createdAt;

  /// Short order handle for the row header and the name fallback.
  String get shortOrderId => shortInstapayOrderId(orderId);

  /// Whether a proof file exists to preview.
  bool get hasProofFile => storagePath.isNotEmpty;

  @override
  List<Object?> get props => [
        proofId,
        paymentId,
        orderId,
        total,
        customerName,
        reference,
        storagePath,
        createdAt,
      ];
}
