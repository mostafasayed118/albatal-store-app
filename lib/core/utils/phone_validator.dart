/// Shared Egyptian-mobile validation for the address forms (address-book
/// dialog, checkout bottom sheet).
///
/// Single source of truth so every address entry point agrees on what
/// "valid" means — same convention as `email_validator.dart` for the auth
/// forms. Top-level (not a closure) so the rule is unit-testable without
/// a widget tree. [invalidMessage] carries the localized copy from the
/// page; the fallback exists only so the validator is testable standalone.
/// Returns null when the value is acceptable.
///
/// Provenance: UX-003 (UI_UX_AUDIT, P0) — COD fulfillment needs a callable
/// number; the address forms previously captured none. The audit's sketch
/// was `01XXXXXXXXX`; the shipped rule is tighter on one digit only (the
/// third), which is exactly the digit separating an Egyptian mobile from
/// a landline: the real allocation is 010 Orange, 011 Vodafone, 012
/// Etisalat, 015 WE.
///
/// Acceptance (after stripping the separators people actually type —
/// spaces, dashes, dots, parentheses):
/// - `01[0125]XXXXXXXX` — the canonical 11-digit local form;
/// - the same number with the Egypt country code attached as `+20`,
///   `0020`, or a bare 12-digit `20…` (customers paste what their
///   contacts app shows them);
/// - the 10-digit national form without the leading zero.
///
/// The store ships domestically, so non-Egyptian country codes are
/// deliberately rejected — this is a policy, not an oversight.
///
/// The value is stored AS TYPED (trimmed): the courier reads the snapshot
/// the customer sees, and migration 065's `phone_digits` generated column
/// already makes the admin directory's digit search separator-proof — no
/// client-side reformat, ever.
String? phoneValidator(String? value, {String? invalidMessage}) {
  var digits = (value ?? '').trim().replaceAll(_separators, '');
  // Optional Egypt country code, in the three spellings people type.
  if (digits.startsWith('+20')) {
    digits = digits.substring(3);
  } else if (digits.startsWith('0020')) {
    digits = digits.substring(4);
  } else if (digits.length == 12 && digits.startsWith('20')) {
    digits = digits.substring(2);
  }
  // Optional leading zero on the national number.
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (!_egMobilePattern.hasMatch(digits)) {
    return invalidMessage ?? 'Enter a valid Egyptian mobile number';
  }
  return null;
}

/// Whitespace and the punctuation phone inputs accumulate. Letters, emoji
/// and other non-digits are left in place so the final pattern rejects them.
final RegExp _separators = RegExp(r'[\s().-]');

/// Egyptian mobile national number: one of the four allocated mobile
/// prefixes, then 8 digits (10 national digits total).
final RegExp _egMobilePattern = RegExp(r'^1[0125]\d{8}$');
