import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/payment_cubit.dart';

/// Web view for Paymob hosted checkout.
///
/// Instead of parsing the WebView callback URL (which can be spoofed),
/// the [PaymentCubit] subscribes to the `payments` table through
/// [PaymentService.watchPaymentStatus]. The webhook
/// (`/paymob-callback`) updates the payment status server-side; the
/// cubit detects the update and emits a terminal [PaymentStatus].
///
/// This page only renders the WebView and reacts to cubit state via
/// [BlocListener]. It does NOT subscribe to Supabase Realtime directly
/// — DB access lives in the data layer (Clean Architecture §1).
class PaymobCheckoutPage extends StatelessWidget {
  const PaymobCheckoutPage({super.key, required this.checkoutUrl});
  final String checkoutUrl;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentCubit, PaymentState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == PaymentStatus.success ||
              current.status == PaymentStatus.failed),
      listener: (context, state) {
        // The cubit's stream listener already emitted the terminal state.
        // Pop back to the previous screen so the user sees the result.
        if (context.canPop()) context.pop();
      },
      child: _CheckoutBody(checkoutUrl: checkoutUrl),
    );
  }
}

/// Stateful body that owns the [WebViewController] lifecycle.
///
/// Extracted from [PaymobCheckoutPage] so the outer widget can remain
/// stateless and own only the side-effect listener.
class _CheckoutBody extends StatefulWidget {
  const _CheckoutBody({required this.checkoutUrl});
  final String checkoutUrl;

  @override
  State<_CheckoutBody> createState() => _CheckoutBodyState();
}

class _CheckoutBodyState extends State<_CheckoutBody> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.completePayment),
        leading: IconButton(
          onPressed: () {
            context.read<PaymentCubit>().cancel();
            context.pop();
          },
          icon: const Icon(Icons.close),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
