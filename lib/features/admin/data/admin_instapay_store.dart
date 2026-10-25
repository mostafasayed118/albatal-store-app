import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../domain/entities/instapay_proof.dart';
import '../domain/repositories/admin_instapay_port.dart';

/// InstaPay proof review for the admin hub (migration 082 + `instapay-review`).
///
/// Reads go through `admin_list_instapay_proofs()` because `payments` is
/// owner-only under RLS — the function joins proof → payment → order →
/// customer server-side and returns zero rows for non-admins. Writes go
/// through the `instapay-review` edge function, which re-checks admin and
/// runs the transactional state flip in `review_instapay_proof`; the client
/// never marks a payment successful itself.
final class SupabaseAdminInstapay implements AdminInstapayPort {
  SupabaseAdminInstapay({required SupabaseClient client}) : _client = client;

  /// Private bucket the submitted screenshots land in (migration 041).
  static const bucket = 'instapay-proofs';

  /// Admin preview lifetime, matching the app's other signed-URL previews.
  static const signedUrlTtlSeconds = 3600;

  final SupabaseClient _client;

  @override
  Future<Result<List<InstapayProof>>> listPendingProofs() =>
      Result.guard(() async {
        final response = await _client.rpc('admin_list_instapay_proofs');
        final rows = response is List ? response : const <dynamic>[];
        // Mistyped rows degrade to skips (same fail-soft contract as the
        // pending-review queue): one malformed join row must not blank the
        // whole review surface.
        final proofs = <InstapayProof>[];
        for (final row in rows) {
          final proof = InstapayProof.tryFromRow(safeMap(row));
          if (proof != null) proofs.add(proof);
        }
        return proofs;
      }, 'Failed to load InstaPay proofs', code: kAdminInstapayLoadFailed);

  @override
  Future<Result<void>> reviewProof(
    String proofId, {
    required bool approve,
    String? note,
  }) async {
    final trimmedNote = note?.trim();
    try {
      final response = await _client.functions.invoke(
        'instapay-review',
        body: {
          'proof_id': proofId,
          'approve': approve,
          if (trimmedNote != null && trimmedNote.isNotEmpty)
            'note': trimmedNote,
        },
      );
      // A 2xx is not sufficient: the edge function contract is
      // `{ok: true, code: 'approved'|'rejected'}`. Treat anything else as
      // a failed review so the row is not silently removed from the queue.
      final data = response.data;
      if (data is Map && data['ok'] == true) return const Success(null);
      return const Failure(AppError(
        'Failed to review the InstaPay proof',
        code: kAdminInstapayReviewFailed,
      ));
    } on FunctionException catch (e) {
      // Classification is the point of this catch block (the same shape as
      // delete-account): a non-2xx edge-function response carries the
      // server's `code` in `details.message`, which maps to a stable code the
      // UI localizes. Anything else collapses to the generic review failure.
      return Failure(AppError(
        'Failed to review the InstaPay proof',
        cause: e,
        code: _reviewFailureCode(e),
      ));
    } catch (e, st) {
      return Failure(AppError(
        'Failed to review the InstaPay proof',
        cause: e,
        stackTrace: st,
        code: kAdminInstapayReviewFailed,
      ));
    }
  }

  @override
  Future<Result<String>> signedProofUrl(String storagePath) =>
      Result.guard(() async {
        final path = storagePath.trim();
        if (path.isEmpty) {
          throw StateError('empty instapay proof path');
        }
        final url = await _client.storage
            .from(bucket)
            .createSignedUrl(path, signedUrlTtlSeconds);
        if (url.trim().isEmpty) {
          throw StateError('empty instapay signed url');
        }
        return url;
      }, 'Failed to load the InstaPay proof',
          code: kAdminInstapayProofUrlFailed);

  /// Maps an edge-function rejection to the feature's stable failure code.
  ///
  /// `details` is the decoded JSON error body, e.g. `{message: 'admin_required'}`.
  /// The status is the fallback when the body is not a map (a proxy or relay
  /// can return plain text).
  String _reviewFailureCode(FunctionException error) {
    final serverCode = switch (error.details) {
      {'message': final String message} => message,
      final String message => message,
      _ => '',
    };
    return switch (serverCode) {
      'admin_required' ||
      'authentication_required' =>
        kAdminInstapayAccessDenied,
      'proof_not_found' => kAdminInstapayProofNotFound,
      'proof_already_reviewed' ||
      'already_reviewed' =>
        kAdminInstapayAlreadyReviewed,
      'payment_not_pending' => kAdminInstapayPaymentNotPending,
      _ => switch (error.status) {
          401 || 403 => kAdminInstapayAccessDenied,
          404 => kAdminInstapayProofNotFound,
          _ => kAdminInstapayReviewFailed,
        },
    };
  }
}
