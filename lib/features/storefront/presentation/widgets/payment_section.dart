import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../cubit/checkout_cubit.dart';

/// Payment method selection with radio tiles.
class PaymentSection extends StatelessWidget {
  const PaymentSection({super.key, required this.payment, required this.l});
  final String payment;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: payment,
      onChanged: (v) => context.read<CheckoutCubit>().payment(v!),
      child: Column(
        children: [
          _paymentTile(l.creditCard, 'Credit Card', context),
          _paymentTile(l.digitalWallet, 'Digital Wallet', context),
          _paymentTile(l.cashOnDelivery, 'Cash on Delivery', context),
        ],
      ),
    );
  }

  Widget _paymentTile(String label, String value, BuildContext context) {
    return ListTile(
      leading: Radio<String>(
        value: value,
      ),
      title: Text(label),
      onTap: () => context.read<CheckoutCubit>().payment(value),
    );
  }
}
