import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/logger.dart';
import '../../domain/paymob_url_guard.dart';

/// Web view for Paymob hosted checkout.
///
/// Instead of parsing the WebView callback URL (which can be spoofed),
/// the [PaymentCubit] subscribes to the `payments` table through
/// [PaymentService.watchPaymentStatus]. The webhook
/// (`/paymob-callback`) updates the payment status server-side; the
/// cubit detects the update and emits a terminal [PaymentStatus].
///
/// This page intentionally does NOT depend on [PaymentCubit]: the cubit
/// is scoped to `/payment-method` (which stays alive underneath this
/// pushed route). [PaymentMethodPage]'s `BlocConsumer` reacts to
/// terminal states — popping this WebView on failure/cancel/timeout
/// and navigating to order-success on success — so the checkout page
/// never needs to read the cubit from its own (sibling) route context.
/// This keeps the trust boundary explicit and avoids a
/// `ProviderNotFoundException` after `context.push`.
class PaymobCheckoutPage extends StatelessWidget {
  const PaymobCheckoutPage({super.key, required this.checkoutUrl});
  final String checkoutUrl;

  @override
  Widget build(BuildContext context) {
    final isSafeUrl = PaymobUrlGuard.isSafePaymobCheckoutUrl(checkoutUrl);
    return isSafeUrl
        ? _CheckoutBody(checkoutUrl: checkoutUrl)
        : const _InvalidCheckoutBody();
  }
}

class _InvalidCheckoutBody extends StatelessWidget {
  const _InvalidCheckoutBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.completePayment)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                context.l10n.invalidCheckoutLink,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: Text(context.l10n.returnToPayment),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stateful body that owns the [WebViewController] lifecycle.
///
/// Extracted from [PaymobCheckoutPage] so the outer widget can remain
/// stateless and own only the side-effect listener.
///
/// On platforms where no [WebViewPlatform] is registered (e.g. widget
/// tests, desktop builds), the WebView is gracefully replaced with a
/// placeholder so the surrounding payment flow can be exercised
/// without an assertion failure in [WebViewController].
class _CheckoutBody extends StatefulWidget {
  const _CheckoutBody({required this.checkoutUrl});
  final String checkoutUrl;

  @override
  State<_CheckoutBody> createState() => _CheckoutBodyState();
}

class _CheckoutBodyState extends State<_CheckoutBody> {
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
