import '../../core/error/failure_codes.dart';
import '../../generated/l10n/app_localizations.dart';

/// The one place that turns an app-authored failure code into shopper-facing
/// copy (audit 2026-09-19, sweep part 32).
///
/// Why this exists rather than a `switch` per page: before it, four surfaces had
/// each grown their own mapping and two of them fell back to matching English
/// literals (`checkout_page.dart` compared `raw == 'Checkout failed'`), so the
/// same failure could read differently per screen and any copy edit silently
/// reverted a screen to English. Adding a code to a new failure is now a
/// one-line change here plus an ARB entry, and the pins in
/// `test/l10n/failure_copy_test.dart` cover every code in both locales.
///
/// Returns null for a code this mapper does not know, which is the signal to the
/// caller that the message is either server-authored (show verbatim) or from a
/// feature that owns its own copy (`payment_error_mapper.dart`).
String? failureCopyForCode(AppLocalizations l10n, String? code) =>
    switch (code) {
      kFailureLoad => l10n.failureLoad,
      kFailureSave => l10n.failureSave,
      kFailureNetwork => l10n.failureNetwork,
      kFailureNotAuthenticated => l10n.failureNotAuthenticated,
      kFailureSessionExpired => l10n.failureSessionExpired,
      kFailureSignInFailed => l10n.failureSignInFailed,
      kFailureSignUpFailed => l10n.failureSignUpFailed,
      kFailureNotFound => l10n.failureNotFound,
      kFailureUnexpected => l10n.failureUnexpected,
      kAuthInvalidCredentials => l10n.authInvalidCredentials,
      kAuthEmailUnconfirmed => l10n.authEmailUnconfirmed,
      kAuthEmailInUse => l10n.authEmailInUse,
      kAuthWeakPassword => l10n.authWeakPassword,
      kDeleteEmailMismatch => l10n.deleteEmailMismatch,
      kDeleteAdminBlocked => l10n.deleteAdminBlocked,
      kDeleteNotOwner => l10n.deleteNotOwner,
      kDeleteFailed => l10n.deleteFailedRetry,
      kAdminAccessDenied => l10n.adminFailureAccessDenied,
      kAdminOrdersLoadFailed => l10n.adminFailureOrdersLoad,
      kAdminOrderLoadFailed => l10n.adminFailureOrderLoad,
      kAdminOrderNotFound => l10n.adminFailureOrderNotFound,
      kAdminOrderStatusInvalid => l10n.adminFailureStatusInvalid,
      kAdminOrderStatusUpdateFailed => l10n.adminFailureStatusUpdate,
      kAdminLowStockLoadFailed => l10n.adminFailureLowStockLoad,
      kAdminSalesLoadFailed => l10n.adminFailureSalesLoad,
      kAdminStockUpdateFailed => l10n.adminFailureStockUpdate,
      kAdminProductsLoadFailed => l10n.adminFailureProductsLoad,
      kAdminProductLoadFailed => l10n.adminFailureProductLoad,
      kAdminCategoriesLoadFailed => l10n.adminFailureCategoriesLoad,
      kAdminProductSaveFailed => l10n.adminFailureProductSave,
      kAdminVariantSaveFailed => l10n.adminFailureVariantSave,
      kAdminImagesSaveFailed => l10n.adminFailureImagesSave,
      kAdminVariantsLoadFailed => l10n.adminFailureVariantsLoad,
      kAdminImagesLoadFailed => l10n.adminFailureImagesLoad,
      kAdminMembershipUpdateFailed => l10n.adminFailureMembershipUpdate,
      kAdminCouponsLoadFailed => l10n.adminFailureCouponsLoad,
      kAdminCouponCreateFailed => l10n.adminFailureCouponCreate,
      kAdminCouponUpdateFailed => l10n.adminFailureCouponUpdate,
      kAdminCustomersLoadFailed => l10n.adminFailureCustomersLoad,
      kAdminReviewsLoadFailed => l10n.adminFailureReviewsLoad,
      kAdminReviewUpdateFailed => l10n.adminFailureReviewUpdate,
      _ => null,
    };

/// The text a failure surface should actually show.
///
/// Precedence, in the order the audit's sweep established:
///  1. localized copy for a known [code] — the app's own wording, never English;
///  2. otherwise [message] verbatim — server-authored prose, or a feature-owned
///     message the caller has already localized;
///  3. otherwise [fallback] — the caller's own guaranteed-localized last resort.
///
/// A blank message counts as absent, because an empty `AppError.message` is a
/// programming slip that must not render as an empty snackbar.
String failureText(
  AppLocalizations l10n, {
  String? code,
  String? message,
  required String fallback,
}) {
  final localized = failureCopyForCode(l10n, code);
  if (localized != null) return localized;
  final raw = message?.trim();
  if (raw != null && raw.isNotEmpty) return raw;
  return fallback;
}
