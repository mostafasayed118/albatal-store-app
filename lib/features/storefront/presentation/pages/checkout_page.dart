import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../data/checkout_service.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/checkout_cubit.dart';
import '../widgets/address_form.dart';
import '../widgets/address_picker.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/cart_summary.dart';
import '../widgets/order_review.dart';
import '../widgets/step_indicator.dart';

/// Checkout page — reviews cart, selects shipping address,
/// then navigates to PaymentMethodPage for payment selection.
///
/// Payment method selection lives on PaymentMethodPage (not here)
/// to avoid the user having to select it twice.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, CheckoutService? checkoutService})
      : _checkoutService = checkoutService;

  final CheckoutService? _checkoutService;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider(
      create: (_) => CheckoutCubit(_checkoutService ?? CheckoutService()),
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
              ],
            ),
            bottomNavigationBar: BottomActionButton(
              label: l.proceedToPayment,
              icon: Icons.arrow_forward,
              isLoading: false,
              onPressed: s.hasAddress
                  ? () => context.push('/payment-method', extra: {
                        'total': context.read<CartCubit>().state.total,
                        'address': s.selectedAddress,
                      })
                  : null,
            ),
          );
        },
      ),
    );
  }
}
