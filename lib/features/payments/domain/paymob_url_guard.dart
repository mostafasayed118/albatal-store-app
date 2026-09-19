/// Pure, WebView-free validation of Paymob hosted-checkout URLs.
///
/// The checkout URL returned by the `paymob-initiate` Edge Function
/// contains a payment token in a query parameter. Before opening it
/// in a WebView we validate that it is:
///   - non-empty,
///   - HTTPS (TLS) — never HTTP,
///   - on an EXACT Paymob-owned host listed in [allowedHosts]
///     (no suffix/subdomain matching — `random.paymob.com` and
///     lookalikes like `accept.paymob.com.evil.com` are rejected).
///
/// This keeps the trust boundary explicit: the WebView is only
/// allowed to load a page on a host the server-side integration
/// actually uses. Unexpected hosts/schemes are rejected rather
/// than silently opened.
///
/// This class is pure Dart so it can be unit-tested without a
/// WebView or network.
class PaymobUrlGuard {
  const PaymobUrlGuard._();

  /// The exact set of Paymob hosts the integration is allowed to open.
  /// Matching is exact-host only (no `*.paymob.com` suffix acceptance):
  /// the WebView loads pages from the same hosts the `paymob-initiate`
  /// Edge Function builds (`accept.paymob.com` iframe + callback flow).
  /// Add a host here only if the Paymob account is migrated to a
  /// new Paymob endpoint and the change is verified.
  static const Set<String> allowedHosts = {
    'accept.paymob.com',
    'secure-egypt.paymob.com',
    'accept.paymobsolutions.com',
  };

  /// True only when [url] is a non-empty HTTPS URL on a Paymob host.
  static bool isSafePaymobCheckoutUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (!uri.isScheme('https')) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    // Exact-host match only: suffix matching would admit any
    // attacker-controlled or lookalike *.paymob.com subdomain
    // (audit finding: open subdomain allowlist).
    return allowedHosts.contains(host);
  }

  /// True when the checkout WebView may navigate to [url].
  ///
  /// The in-page counterpart of [isSafePaymobCheckoutUrl] — deliberately
  /// the same rules (HTTPS on a Paymob-owned host), implemented by
  /// delegation so the host allowlist lives in exactly ONE place. The
  /// checkout page's navigation delegate used to keep its own inline
  /// copy of these checks, which could silently drift from this list
  /// (audit finding: duplicated allowlist).
  static bool isSafeWebViewNavigationTarget(String url) =>
      isSafePaymobCheckoutUrl(url);

  /// Redact the payment token from [url] so a safe, host-only label
  /// can be logged without leaking the sensitive token.
  static String redact(String url) {
    if (url.trim().isEmpty) return '<invalid-url>';
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return '<invalid-url>';
    final params = Map<String, String>.from(uri.queryParameters);
    for (final key in const ['payment_token', 'token', 'iframe_id']) {
      if (params.containsKey(key)) params[key] = '<redacted>';
    }
    return uri.replace(queryParameters: params).toString();
  }
}
