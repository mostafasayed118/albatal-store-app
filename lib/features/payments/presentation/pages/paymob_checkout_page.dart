import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/payment_cubit.dart';

/// Web view for Paymob hosted checkout page.
///
/// Instead of parsing the WebView callback URL (which can be spoofed),
/// we subscribe to the `payments` table via Supabase Realtime. The
/// webhook (`/paymob-callback`) updates the payment status server-side;
/// the client reads the authoritative status from the database.
class PaymobCheckoutPage extends StatefulWidget {
  const PaymobCheckoutPage({super.key, required this.checkoutUrl});
  final String checkoutUrl;

  @override
  State<PaymobCheckoutPage> createState() => _PaymobCheckoutPageState();
}

class _PaymobCheckoutPageState extends State<PaymobCheckoutPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  RealtimeChannel? _paymentChannel;

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

    _subscribeToPaymentStatus();
  }

  /// Subscribe to the payments table for the current order's payment.
  /// When the webhook updates the status, we detect it here and navigate.
  void _subscribeToPaymentStatus() {
    final orderId = context.read<PaymentCubit>().state.orderId;
    final paymentCubit = context.read<PaymentCubit>();

    _paymentChannel = Supabase.instance.client
        .channel('payment-$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newRecord = payload.newRecord;
            final status = newRecord['status'] as String?;

            if (status == 'success') {
              final transactionId =
                  newRecord['transaction_id'] as String? ?? '';
              paymentCubit.handleCallback(
                'success=true&id=$transactionId',
              );
              Navigator.of(context).pop();
            } else if (status == 'failed') {
              paymentCubit.handleCallback('success=false');
              Navigator.of(context).pop();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _paymentChannel?.unsubscribe();
    super.dispose();
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
