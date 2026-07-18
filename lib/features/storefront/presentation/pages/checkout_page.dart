import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/orders_cubit.dart';
import '../widgets/address_form.dart';
import '../widgets/address_picker.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/cart_summary.dart';
import '../widgets/order_review.dart';
import '../widgets/step_indicator.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider(
      create: (_) => CheckoutCubit(),
      child: BlocConsumer<CheckoutCubit, CheckoutState>(
        listener: (context, s) {
          if (s.status == CheckoutStatus.success) {
            final cart = context.read<CartCubit>().state;
            final order = context.read<OrdersCubit>().place(
                  cart,
                  paymentMethod: s.payment,
                  address: s.selectedAddress,
                );
            context.read<CartCubit>().clear();
            context.go('/order-success', extra: order.id);
          }
        },
        builder: (context, s) {
          final addressError =
              s.status == CheckoutStatus.error && !s.hasAddress;
          return Scaffold(
            appBar: AppBar(title: Text(l.checkout)),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StepIndicator(
                  steps: [l.shippingAddress, l.paymentMethod, l.confirmStep],
                  currentStep: s.step,
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
                Text(l.paymentMethod,
                    style: Theme.of(context).textTheme.titleLarge),
                _PaymentSection(payment: s.payment, l: l),
                const SizedBox(height: 16),
                if (s.hasAddress) ...[
                  Text(l.reviewOrder,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  OrderReview(address: s.selectedAddress!, l: l),
                  const SizedBox(height: 16),
                ],
                BlocBuilder<CartCubit, CartState>(
                    builder: (_, cart) => CartSummary(cart)),
              ],
            ),
            bottomNavigationBar: BottomActionButton(
              label: l.confirmAndPay,
              icon: Icons.lock_outline,
              isLoading: s.status == CheckoutStatus.placing,
              onPressed: s.hasAddress
                  ? () => context.read<CheckoutCubit>().place()
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.payment, required this.l});
  final String payment;
  final dynamic l;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _paymentTile(l.creditCard, 'Credit Card', payment, context),
        _paymentTile(l.digitalWallet, 'Digital Wallet', payment, context),
        _paymentTile(l.cashOnDelivery, 'Cash on Delivery', payment, context),
      ],
    );
  }

  Widget _paymentTile(
      String label, String value, String groupValue, BuildContext context) {
    return ListTile(
      leading: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: (v) => context.read<CheckoutCubit>().payment(v!),
      ),
      title: Text(label),
      onTap: () => context.read<CheckoutCubit>().payment(value),
    );
  }
}
