/// Shared email validation for the auth forms (sign-in, sign-up,
/// forgot-password).
///
/// Single source of truth so every auth entry point agrees on what "valid"
/// means — previously each page hand-rolled its own `contains('@')`
/// closure. Top-level (not a closure) so the rule is unit-testable without
/// a widget tree. [invalidMessage] carries the localized copy from the
/// page; the fallback exists only so the validator is testable standalone.
/// Returns null when the value is acceptable.
///
/// The rule is a pragmatic RFC-5322-lite (WHATWG/HTML5 style): a dot
/// separated local part, an `@`, one or more dot-separated domain labels,
/// and an alphabetic TLD of 2+ characters — tightened from the old
/// "contains @" check which accepted `'@'` and `'a@b'` (audit
/// 2026-09-14). Full RFC-5322 (quoted local parts, IP-literal domains)
/// is deliberately NOT supported; the goal is to match what Supabase
/// accepts in practice.
String? emailValidator(String? value, {String? invalidMessage}) {
  final trimmed = (value ?? '').trim();

  // Length caps before the regex: 254 total (RFC 5321 path limit) and
  // 64 for the local part (RFC 5321 §4.5.3.1.1).
  final at = trimmed.indexOf('@');
  if (trimmed.isEmpty ||
      trimmed.length > 254 ||
      (at < 0 || at > 64) ||
      !_emailPattern.hasMatch(trimmed)) {
    return invalidMessage ?? 'Please enter a valid email';
  }
  return null;
}

/// Dot-separated local atoms + labeled domain + alphabetic TLD (2-63
/// letters). Rejects consecutive dots, leading/trailing dots, empty
/// labels, and numeric-only TLDs.
final RegExp _emailPattern = RegExp(
  r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*"
  r'@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$',
);
