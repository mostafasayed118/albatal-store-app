import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
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
          if (s.step == 2) {
            final cart = context.read<CartCubit>().state;
            final order = context
                .read<OrdersCubit>()
                .place(cart, paymentMethod: s.payment);
            context.read<CartCubit>().clear();
            context.go('/order-success', extra: order.id);
          }
        },
        builder: (context, s) => Scaffold(
          appBar: AppBar(title: Text(l.checkout)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [l.shippingAddress, l.paymentMethod, l.confirmStep]
                    .asMap()
                    .entries
                    .map((e) => Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: e.key <= s.step
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                foregroundColor: e.key <= s.step
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                                child: Text('${e.key + 1}'),
                              ),
                              const SizedBox(height: 4),
                              Text(e.value),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(l.shippingAddress,
                  style: Theme.of(context).textTheme.titleLarge),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(s.addressName),
                  subtitle: Text(s.addressLine),
                  trailing: Icon(Icons.check_circle, color: scheme.primary),
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final address = await AddressForm.show(context);
                  if (address != null && context.mounted) {
                    context.read<CheckoutCubit>().setAddress(address);
                  }
                },
                child: Text(l.addNewAddress),
              ),
              const SizedBox(height: 24),
              Text(l.paymentMethod,
                  style: Theme.of(context).textTheme.titleLarge),
              RadioGroup<String>(
                groupValue: s.payment,
                onChanged: (v) => context.read<CheckoutCubit>().payment(v!),
                child: Column(
                  children: ['Credit Card', 'Digital Wallet', 'Cash on Delivery']
                      .map((x) => ListTile(
                            leading: Radio<String>(
                                value: x,
                                groupRegistry: RadioGroup.maybeOf<String>(context)),
                            title: Text(x),
                            onTap: () => context.read<CheckoutCubit>().payment(x),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              BlocBuilder<CartCubit, CartState>(
                  builder: (_, cart) => CartSummary(cart)),
            ],
          ),
          bottomNavigationBar: BottomActionButton(
            label: l.placeOrder,
            icon: Icons.lock_outline,
            isLoading: s.placing,
            onPressed: () => context.read<CheckoutCubit>().place(),
          ),
        ),
      ),
    );
  }
}
