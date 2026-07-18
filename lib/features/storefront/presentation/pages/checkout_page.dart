import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/address.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../addresses/presentation/cubit/addresses_cubit.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/orders_cubit.dart';
import '../widgets/address_form.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/cart_summary.dart';

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
                // Step indicators
                _StepIndicator(
                  steps: [l.shippingAddress, l.paymentMethod, l.confirmStep],
                  currentStep: s.step,
                  scheme: scheme,
                ),
                const SizedBox(height: 24),

                // ── Shipping Address ──
                Text(l.shippingAddress,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _AddressPicker(
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

                // ── Payment Method ──
                Text(l.paymentMethod,
                    style: Theme.of(context).textTheme.titleLarge),
                RadioGroup<String>(
                  groupValue: s.payment,
                  onChanged: (v) =>
                      context.read<CheckoutCubit>().payment(v!),
                  child: Column(
                    children: [
                      _paymentTile(l.creditCard, 'Credit Card', s.payment,
                          scheme, context),
                      _paymentTile(l.digitalWallet, 'Digital Wallet',
                          s.payment, scheme, context),
                      _paymentTile(l.cashOnDelivery, 'Cash on Delivery',
                          s.payment, scheme, context),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Order Review ──
                if (s.hasAddress) ...[
                  Text(l.reviewOrder,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _OrderReview(address: s.selectedAddress!, l: l),
                  const SizedBox(height: 16),
                ],

                // ── Cart Summary ──
                BlocBuilder<CartCubit, CartState>(
                    builder: (_, cart) => CartSummary(cart)),
              ],
            ),
            bottomNavigationBar: BottomActionButton(
              label: l.confirmAndPay,
              icon: Icons.lock_outline,
              isLoading: s.status == CheckoutStatus.placing,
              onPressed: () {
                if (!s.hasAddress) {
                  // Force step back to shipping to show the error
                  return;
                }
                context.read<CheckoutCubit>().place();
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── Step Indicator ──────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.steps,
    required this.currentStep,
    required this.scheme,
  });
  final List<String> steps;
  final int currentStep;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: steps.asMap().entries.map((e) {
        final active = e.key <= currentStep;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    active ? scheme.primary : scheme.surfaceContainerHighest,
                foregroundColor:
                    active ? scheme.onPrimary : scheme.onSurface,
                child: Text('${e.key + 1}'),
              ),
              const SizedBox(height: 4),
              Text(e.value, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Address Picker ─────────────────────────────────────────────────

class _AddressPicker extends StatelessWidget {
  const _AddressPicker({
    required this.selectedAddress,
    required this.onSelect,
    required this.onAddNew,
    required this.l,
    required this.scheme,
    required this.hasError,
  });

  final Address? selectedAddress;
  final ValueChanged<Address> onSelect;
  final VoidCallback onAddNew;
  final AppLocalizations l;
  final ColorScheme scheme;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddressesCubit, AddressesState>(
      builder: (context, state) {
        if (state.addresses.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.location_off_outlined,
                      size: 40, color: scheme.outline),
                  const SizedBox(height: 8),
                  Text(l.noAddressesSaved,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onAddNew,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l.addAddress),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            ...state.addresses.map((a) {
              final isSelected = selectedAddress?.id == a.id;
              return Card(
                color: isSelected
                    ? scheme.primaryContainer.withValues(alpha: .3)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? scheme.primary
                        : hasError
                            ? scheme.error
                            : scheme.outline.withValues(alpha: .3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(
                    a.isDefault ? Icons.home : Icons.location_on_outlined,
                    color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(a.recipient,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (a.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(l.defaultLabel,
                              style: TextStyle(
                                  fontSize: 10, color: scheme.primary)),
                        ),
                    ],
                  ),
                  subtitle: Text('${a.line}, ${a.city}, ${a.country}'),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: scheme.primary)
                      : Icon(Icons.radio_button_unchecked,
                          color: scheme.outline),
                  onTap: () => onSelect(a),
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddNew,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.addNewAddress),
            ),
          ],
        );
      },
    );
  }
}

// ─── Payment Tile ───────────────────────────────────────────────────

Widget _paymentTile(String label, String value, String groupValue,
    ColorScheme scheme, BuildContext context) {
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

// ─── Order Review ───────────────────────────────────────────────────

class _OrderReview extends StatelessWidget {
  const _OrderReview({required this.address, required this.l});
  final Address address;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(l.shippingTo,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: scheme.onSurface)),
              ],
            ),
            const SizedBox(height: 4),
            Text(address.recipient,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${address.line}, ${address.city}, ${address.country}',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
