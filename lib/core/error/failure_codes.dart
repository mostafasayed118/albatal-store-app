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
