/// Codes for failures the APP authored, so the UI can localize them without
/// matching English text.
///
/// The rule this file exists to make explicit (audit 2026-09-19, sweep part 32):
///
///  * **App-authored message + code** → the presentation layer resolves copy
///    from the code, and the English `AppError.message` is diagnosis only, never
///    displayed.
///  * **No code** → the message came from the server (a PostgREST rejection, an
///    edge-function body) and is shown **verbatim**, per the P1 ruling recorded in
///    `checkout_page.dart`. The app does not translate server prose.
///
/// So "which of the two is this?" is answered by `code != null`, not by guessing
/// from the shape of the string. Anything the app itself words must carry a code
/// here or in its feature (see `kCheckoutFailedCode`, `kReviewUnavailableCode`);
/// anything the server words must not.
///
/// Codes are wire-stable strings: they travel through cubit state and are
/// compared in tests, and the payment path already treats them as protocol
/// (`payment_error_mapper.dart` matches server-sent codes).
library;

/// A read/load failed for a reason the app cannot classify further.
const kFailureLoad = 'load_failed';

/// A write/save failed for a reason the app cannot classify further.
const kFailureSave = 'save_failed';

/// The request never reached a usable response — timeout or transport failure.
const kFailureNetwork = 'network_timeout';

/// There is no usable session for an action that needs one.
const kFailureNotAuthenticated = 'not_authenticated';

/// The session existed and is no longer valid; the shopper must sign in again.
const kFailureSessionExpired = 'session_expired';

/// Sign-in was attempted and did not succeed.
const kFailureSignInFailed = 'sign_in_failed';

/// Sign-up was attempted and did not succeed.
const kFailureSignUpFailed = 'sign_up_failed';

/// The requested record does not exist (or is not visible to this shopper).
const kFailureNotFound = 'not_found';

/// The catch-all for auth-provider failures, including any provider string the
/// app does not recognize — `_mapAuthError` deliberately never surfaces those
/// verbatim, so they collapse here rather than leaking provider wording.
const kFailureUnexpected = 'unexpected_error';

/// The provider rejected the email/password pair.
const kAuthInvalidCredentials = 'auth_invalid_credentials';

/// The account exists but its email has not been confirmed.
const kAuthEmailUnconfirmed = 'auth_email_unconfirmed';

/// Sign-up was rejected because the email already has an account.
const kAuthEmailInUse = 'auth_email_in_use';

/// The provider rejected the password as too weak.
const kAuthWeakPassword = 'auth_weak_password';

/// Account deletion was refused because the typed email does not match.
const kDeleteEmailMismatch = 'delete_email_mismatch';

/// Account deletion was refused because the account is an admin.
const kDeleteAdminBlocked = 'delete_admin_blocked';

/// Account deletion was refused because the caller passed another user's id.
const kDeleteNotOwner = 'delete_not_owner';

/// Account deletion failed for a reason the app cannot classify further.
const kDeleteFailed = 'delete_failed';

// ─── Admin console (owner decision, part 34-35: the admin surface is localized
// like the storefront, so its own wordings carry codes too). ───

/// The admin gate refused the action.
const kAdminAccessDenied = 'admin_access_denied';

/// The order queue did not load.
const kAdminOrdersLoadFailed = 'admin_orders_load_failed';

/// One order did not load.
const kAdminOrderLoadFailed = 'admin_order_load_failed';

/// The requested order does not exist.
const kAdminOrderNotFound = 'admin_order_not_found';

/// The status value is not one the app knows.
const kAdminOrderStatusInvalid = 'admin_order_status_invalid';

/// An order-status write failed.
const kAdminOrderStatusUpdateFailed = 'admin_order_status_update_failed';

/// The low-stock list did not load.
const kAdminLowStockLoadFailed = 'admin_low_stock_load_failed';

/// The sales overview did not load.
const kAdminSalesLoadFailed = 'admin_sales_load_failed';

/// A stock write failed.
const kAdminStockUpdateFailed = 'admin_stock_update_failed';

/// The product list did not load.
const kAdminProductsLoadFailed = 'admin_products_load_failed';

/// One product did not load.
const kAdminProductLoadFailed = 'admin_product_load_failed';

/// The category list did not load.
const kAdminCategoriesLoadFailed = 'admin_categories_load_failed';

/// A product upsert failed.
const kAdminProductSaveFailed = 'admin_product_save_failed';

/// A variant upsert failed.
const kAdminVariantSaveFailed = 'admin_variant_save_failed';

/// An image-list write failed.
const kAdminImagesSaveFailed = 'admin_images_save_failed';

/// A product's variants did not load.
const kAdminVariantsLoadFailed = 'admin_variants_load_failed';

/// A product's images did not load.
const kAdminImagesLoadFailed = 'admin_images_load_failed';

/// A membership-tier write failed.
const kAdminMembershipUpdateFailed = 'admin_membership_update_failed';

/// The coupon list did not load.
const kAdminCouponsLoadFailed = 'admin_coupons_load_failed';

/// A coupon insert failed.
const kAdminCouponCreateFailed = 'admin_coupon_create_failed';

/// A coupon update failed.
const kAdminCouponUpdateFailed = 'admin_coupon_update_failed';

/// The customer directory did not load.
const kAdminCustomersLoadFailed = 'admin_customers_load_failed';

/// The pending-review queue did not load.
const kAdminReviewsLoadFailed = 'admin_reviews_load_failed';

/// A review-status write failed.
const kAdminReviewUpdateFailed = 'admin_review_update_failed';
