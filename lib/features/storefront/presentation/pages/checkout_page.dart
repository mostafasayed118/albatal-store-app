import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/checkout_cubit.dart';
import '../widgets/address_form.dart';
import '../widgets/address_picker.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/cart_summary.dart';
import '../widgets/order_review.dart';
import '../widgets/payment_section.dart';
import '../widgets/step_indicator.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider(
      create: (_) => CheckoutCubit(),
      child: BlocBuilder<CheckoutCubit, CheckoutState>(
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
                PaymentSection(payment: s.payment, l: l),
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
              label: l.proceedToPayment,
              icon: Icons.arrow_forward,
              isLoading: false,
              onPressed: s.hasAddress
                  ? () => context.push('/payment-method',
                      extra: context.read<CartCubit>().state.total)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
