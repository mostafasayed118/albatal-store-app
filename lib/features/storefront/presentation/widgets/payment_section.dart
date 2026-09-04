import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../payments/domain/entities/payment.dart';
import '../cubit/checkout_cubit.dart';

/// Payment method selection with radio tiles.
///
/// Values are [PaymentMethod] members — the cubit maps them to the
/// canonical server strings via [PaymentMethod.serverValue], so no
/// free-form strings can reach the checkout RPC.
class PaymentSection extends StatelessWidget {
  const PaymentSection({super.key, required this.payment, required this.l});
  final PaymentMethod payment;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<PaymentMethod>(
      groupValue: payment,
      onChanged: (v) => context.read<CheckoutCubit>().payment(v!),
      child: Column(
        children: [
          _paymentTile(l.creditCard, PaymentMethod.paymobCard, context),
          _paymentTile(l.cashOnDelivery, PaymentMethod.cashOnDelivery, context),
        ],
      ),
    );
  }

  Widget _paymentTile(String label, PaymentMethod value, BuildContext context) {
    return ListTile(
      leading: Radio<PaymentMethod>(
        value: value,
      ),
      title: Text(label),
      onTap: () => context.read<CheckoutCubit>().payment(value),
    );
  }
}
