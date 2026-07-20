import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/supabase_config.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/checkout_cubit.dart';
import '../widgets/address_form.dart';
import '../widgets/address_picker.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/cart_summary.dart';
import '../widgets/order_review.dart';
import '../widgets/step_indicator.dart';

/// Checkout page — reviews cart, selects shipping address,
/// then creates a pending server-side order and navigates to
/// PaymentMethodPage with the real orderId + server-computed total.
///
/// The idempotency key is managed by [CheckoutCubit] — it is
/// generated once per checkout attempt and reused on retry, so
/// the server returns the original order instead of creating a
/// duplicate.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, CheckoutRepository? checkoutRepository})
      : _checkoutRepository = checkoutRepository;

  final CheckoutRepository? _checkoutRepository;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider(
      create: (_) => CheckoutCubit(_checkoutRepository ?? getIt<CheckoutRepository>()),
      child: BlocConsumer<CheckoutCubit, CheckoutState>(
        listener: (context, s) {
          // When the pending order is created, navigate to payment with
          // the real orderId and server-computed total.
          if (s.status == CheckoutStatus.placing && s.hasPendingOrder) {
            final email = SupabaseConfig.currentUser?.email ??
                'customer@example.com';
            context.push('/payment-method', extra: {
              'total': s.serverTotal,
              'subtotal': s.serverSubtotal,
              'shipping': s.serverShipping,
              'address': s.selectedAddress,
              'orderId': s.pendingOrderId,
              'customerEmail': email,
            });
          } else if (s.status == CheckoutStatus.error &&
              s.errorMessage != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(s.errorMessage!)));
          }
        },
        builder: (context, s) {
          final addressError =
              s.status == CheckoutStatus.error && !s.hasAddress;
          final isCreating = s.status == CheckoutStatus.creatingOrder;
          return Scaffold(
            appBar: AppBar(title: Text(l.checkout)),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StepIndicator(
                  steps: [l.shippingAddress, l.reviewOrder],
                  currentStep: s.hasAddress ? 1 : 0,
                  scheme: scheme,
                ),
                const SizedBox(height: 24),
                Text(l.shippingAddress,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                AddressPicker(
                  selectedAddress: s.selectedAddress,
                  onSelect: (a) =>
                      context.read<CheckoutCubit>().selectAddress(a),
                  onAddNew: () async {
                    final address = await AddressForm.show(context);
                    if (address != null && context.mounted) {
                      context.read<CheckoutCubit>().selectAddress(address);
                    }
                  },
                  l: l,
                  scheme: scheme,
                  hasError: addressError,
                ),
                if (addressError) ...[
                  const SizedBox(height: 4),
                  Text(l.validationSelectAddress,
                      style: TextStyle(color: scheme.error, fontSize: 12)),
                ],
                const SizedBox(height: 24),
                if (s.hasAddress) ...[
                  Text(l.reviewOrder,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  OrderReview(address: s.selectedAddress!, l: l),
                  const SizedBox(height: 16),
                ],
                BlocBuilder<CartCubit, CartState>(
                    builder: (_, cart) => CartSummary(cart)),
                // Show server-returned totals once the order is created
                if (s.hasPendingOrder) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Server-confirmed totals',
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          _ServerTotalRow(
                              label: 'Subtotal', value: s.serverSubtotal),
                          _ServerTotalRow(
                              label: 'Shipping', value: s.serverShipping),
                          _ServerTotalRow(
                              label: 'Total', value: s.serverTotal),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            bottomNavigationBar: BottomActionButton(
              label: l.proceedToPayment,
              icon: Icons.arrow_forward,
              isLoading: isCreating,
              onPressed: s.hasAddress && !isCreating
                  ? () {
                      final cart = context.read<CartCubit>().state;
                      // The cubit manages the idempotency key —
                      // it generates one on the first call and
                      // reuses it on retry.
                      context.read<CheckoutCubit>().createPendingOrder(
                            cartItems: cart.items,
                          );
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _ServerTotalRow extends StatelessWidget {
  const _ServerTotalRow({required this.label, required this.value});
  final String label;
  final Money? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value?.format() ?? '--',
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
