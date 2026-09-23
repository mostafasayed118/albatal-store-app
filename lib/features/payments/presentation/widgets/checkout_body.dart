import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/logger.dart';
import '../../domain/paymob_url_guard.dart';

/// Stateful body that owns the [WebViewController] lifecycle.
///
/// Extracted from `paymob_checkout_page.dart` (was private `_CheckoutBody`)
/// so the outer widget can remain stateless and own only the guard.
///
/// On platforms where no [WebViewPlatform] is registered (e.g. widget
/// tests, desktop builds), the WebView is gracefully replaced with a
/// placeholder so the surrounding payment flow can be exercised
/// without an assertion failure in [WebViewController].
class CheckoutBody extends StatefulWidget {
  const CheckoutBody({super.key, required this.checkoutUrl});
  final String checkoutUrl;

  @override
  State<CheckoutBody> createState() => CheckoutBodyState();
}

/// Public state so widget tests can drive the body if needed.
/// Not part of the public API contract — prefer pumping [CheckoutBody].
class CheckoutBodyState extends State<CheckoutBody> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    assert(PaymobUrlGuard.isSafePaymobCheckoutUrl(widget.checkoutUrl));
    // Guard: [WebViewController] asserts that a [WebViewPlatform]
    // has been registered. In widget tests (and desktop builds) no
    // platform plugin is available — skip construction and render a
    // safe placeholder so the payment flow remains testable.
    if (WebViewPlatform.instance == null) return;
    _controller = WebViewController()
      // Paymob's hosted checkout is a JS-driven iframe flow (3-D Secure
      // challenges, card-token inputs): it cannot render with JavaScript
      // disabled, so `unrestricted` is intentional here. The trust
      // boundary is NOT the JS mode — it is the URL allowlist
      // ([PaymobUrlGuard], enforced on entry AND on every navigation
      // below) plus the server-side webhook: success is observed only
      // through `payments` row updates, never through WebView URLs.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            // Single source of truth for the host allowlist lives in
            // [PaymobUrlGuard] — the page must not re-implement it
            // (audit finding: duplicated allowlist).
            return PaymobUrlGuard.isSafeWebViewNavigationTarget(request.url)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          // SPA-style same-document redirects never hit
          // [onNavigationRequest]: re-check every URL change against the
          // same guard. This callback cannot prevent the navigation, so
          // an off-allowlist URL is logged (token-redacted) for
          // diagnostics; the payment outcome still comes only from the
          // server-side `payments` watch, never from this URL.
          onUrlChange: (change) {
            final url = change.url;
            if (url == null) return;
            if (!PaymobUrlGuard.isSafeWebViewNavigationTarget(url)) {
              Log.w(
                'Paymob WebView left the allowlist: '
                '${PaymobUrlGuard.redact(url)}',
                category: LogCategory.payment,
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.completePayment),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: controller == null
          ? Center(
              child: Text(
                context.l10n.completePayment,
                textAlign: TextAlign.center,
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: controller),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
