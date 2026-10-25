import '../../../../core/error/result.dart';
import '../entities/instapay_proof.dart';

// ─── InstaPay review failures ────────────────────────────────────────────────
//
// Feature-owned codes: the admin surface localizes this queue itself (the
// shared `failure_codes.dart` stays the home for cross-feature classes), and
// the cubit carries these through state so the page never matches English
// prose. Wire-stable: tests compare them.

/// The pending-proof queue did not load.
const kAdminInstapayLoadFailed = 'admin_instapay_load_failed';

/// A review write failed for a reason the app cannot classify further.
const kAdminInstapayReviewFailed = 'admin_instapay_review_failed';

/// The proof preview URL could not be minted.
const kAdminInstapayProofUrlFailed = 'admin_instapay_proof_url_failed';

/// The caller is not an admin (edge function 403 / `admin_required`).
const kAdminInstapayAccessDenied = 'admin_instapay_access_denied';

/// The proof no longer exists (404 / `proof_not_found`).
const kAdminInstapayProofNotFound = 'admin_instapay_proof_not_found';

/// The proof was already approved or rejected (`proof_already_reviewed`).
const kAdminInstapayAlreadyReviewed = 'admin_instapay_already_reviewed';

/// The payment is no longer pending (`payment_not_pending`).
const kAdminInstapayPaymentNotPending = 'admin_instapay_payment_not_pending';

/// Narrow port for the InstaPay proof review queue (ISP).
///
/// The page depends on this instead of `AdminRepository`: listing, reviewing
/// and previewing a proof are one concern, and the edge function/RPC that
/// back them are already server-authoritative (the client never decides
/// payment success).
abstract interface class AdminInstapayPort {
  /// Pending proofs, oldest first (server caps the queue at 100).
  Future<Result<List<InstapayProof>>> listPendingProofs();

  /// Approves/rejects [proofId] through `instapay-review`; on approval the
  /// server flips the payment and order atomically. [note] is the optional
  /// reviewer note stored on the proof.
  Future<Result<void>> reviewProof(
    String proofId, {
    required bool approve,
    String? note,
  });

  /// Time-limited signed URL for [storagePath] in the private
  /// `instapay-proofs` bucket.
  Future<Result<String>> signedProofUrl(String storagePath);
}
