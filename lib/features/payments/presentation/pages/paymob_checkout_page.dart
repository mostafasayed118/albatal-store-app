import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/payment_cubit.dart';

/// Web view for Paymob hosted checkout page.
class PaymobCheckoutPage extends StatefulWidget {
  const PaymobCheckoutPage({super.key, required this.checkoutUrl});
  final String checkoutUrl;

  @override
  State<PaymobCheckoutPage> createState() => _PaymobCheckoutPageState();
}

class _PaymobCheckoutPageState extends State<PaymobCheckoutPage> {
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
          onNavigationRequest: (request) {
            final url = request.url;
            // Check for Paymob callback URL
            if (url.contains('paymob') && url.contains('response')) {
              context.read<PaymentCubit>().handleCallback(url);
              context.pop();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
