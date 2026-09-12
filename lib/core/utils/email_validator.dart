/// Shared email validation for the auth forms (sign-in, sign-up,
/// forgot-password).
///
/// Single source of truth so every auth entry point agrees on what "valid"
/// means — previously each page hand-rolled its own `contains('@')`
/// closure. Top-level (not a closure) so the rule is unit-testable without
/// a widget tree. [invalidMessage] carries the localized copy from the
/// page; the fallback exists only so the validator is testable standalone.
/// Returns null when the value is acceptable.
String? emailValidator(String? value, {String? invalidMessage}) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty || !trimmed.contains('@')) {
    return invalidMessage ?? 'Please enter a valid email';
  }
  return null;
}
