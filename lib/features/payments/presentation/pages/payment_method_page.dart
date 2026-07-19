import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/payment.dart';
import '../../data/vodafone_cash_payment_service.dart';
import '../cubit/payment_cubit.dart';
import '../../../storefront/presentation/cubit/cart_cubit.dart';
import '../../../storefront/presentation/cubit/checkout_cubit.dart';
import '../../../storefront/presentation/cubit/orders_cubit.dart';

/// Payment method selection page.
class PaymentMethodPage extends StatelessWidget {
  const PaymentMethodPage({super.key, required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return BlocProvider(
      create: (_) => PaymentCubit(
        VodafoneCashPaymentService(
          merchantCode: const String.fromEnvironment('VODAFONE_CASH_MERCHANT_CODE', defaultValue: ''),
          apiKey: const String.fromEnvironment('VODAFONE_CASH_API_KEY', defaultValue: ''),
        ),
      )..initPayment(amount: amount, orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}'),
      child: BlocConsumer<PaymentCubit, PaymentState>(
        listener: (context, state) {
          if (state.status == PaymentStatus.success) {
            // Create order from cart
            final cart = context.read<CartCubit>().state;
            final checkoutState = context.read<CheckoutCubit>().state;
            context.read<OrdersCubit>().place(
                  cart,
                  paymentMethod: state.selectedMethod?.name ?? 'unknown',
                  address: checkoutState.selectedAddress,
                );
            context.read<CartCubit>().clear();
            context.go('/order-success');
          } else if (state.status == PaymentStatus.failed &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text(l.selectPaymentMethod)),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l.selectPaymentMethod,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('${l.total}: ${state.amount.toStringAsFixed(0)} EGY',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary)),
                const SizedBox(height: 24),
                _PaymentOption(
                  icon: Icons.credit_card,
                  title: l.payWithCard,
                  subtitle: l.payWithCardDescription,
                  isSelected: state.selectedMethod == PaymentMethod.paymobCard,
                  onTap: () => context
                      .read<PaymentCubit>()
                      .selectMethod(PaymentMethod.paymobCard),
                ),
                const SizedBox(height: 12),
                _PaymentOption(
                  icon: Icons.phone_android,
                  title: l.payWithVodafoneCash,
                  subtitle: l.payWithVodafoneCashDescription,
                  isSelected:
                      state.selectedMethod == PaymentMethod.vodafoneCash,
                  onTap: () => context
                      .read<PaymentCubit>()
                      .selectMethod(PaymentMethod.vodafoneCash),
                ),
                const SizedBox(height: 12),
                _PaymentOption(
                  icon: Icons.money,
                  title: l.cashOnDelivery,
                  subtitle: l.cashOnDeliveryDescription,
                  isSelected:
                      state.selectedMethod == PaymentMethod.cashOnDelivery,
                  onTap: () => context
                      .read<PaymentCubit>()
                      .selectMethod(PaymentMethod.cashOnDelivery),
                ),
                const SizedBox(height: 32),
                BlocBuilder<PaymentCubit, PaymentState>(
                  builder: (context, state) {
                    return FilledButton(
                      onPressed: state.canProceed &&
                              state.status != PaymentStatus.processing
                          ? () => context.read<PaymentCubit>().processPayment(
                                customerEmail: 'customer@example.com',
                              )
                          : null,
                      child: state.status == PaymentStatus.processing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.payNow),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: .3)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? scheme.primary : scheme.outline.withValues(alpha: .3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : Icon(Icons.radio_button_unchecked, color: scheme.outline),
        onTap: onTap,
      ),
    );
  }
}
