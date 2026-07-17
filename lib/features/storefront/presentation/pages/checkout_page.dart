import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/cart_cubit.dart';
import '../cubit/checkout_cubit.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/cart_summary.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => CheckoutCubit(),
        child: BlocConsumer<CheckoutCubit, CheckoutState>(
          listener: (context, s) {
            if (s.step == 2) {
              context.read<CartCubit>().clear();
              context.go('/order-success');
            }
          },
          builder: (context, s) => Scaffold(
            appBar: AppBar(title: const Text('Checkout')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: ['Shipping', 'Payment', 'Confirm']
                      .asMap()
                      .entries
                      .map((e) => Expanded(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: e.key <= s.step ? Theme.of(context).colorScheme.primary : null,
                                  child: Text('${e.key + 1}'),
                                ),
                                Text(e.value),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                Text('Shipping Address', style: Theme.of(context).textTheme.titleLarge),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.location_on_outlined),
                    title: Text('Ahmed Mansour'),
                    subtitle: Text('12 El Tahrir Street, Cairo, Egypt'),
                    trailing: Icon(Icons.check_circle, color: Color(0xFF064E3B)),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AlertDialog(
                      title: Text('Add New Address'),
                      content: Text('Address entry is simulated in this local mock.'),
                    ),
                  ),
                  child: const Text('Add New Address'),
                ),
                const SizedBox(height: 24),
                Text('Payment Method', style: Theme.of(context).textTheme.titleLarge),
                RadioGroup<String>(
                  groupValue: s.payment,
                  onChanged: (v) => context.read<CheckoutCubit>().payment(v!),
                  child: Column(
                    children: ['Credit Card', 'Digital Wallet', 'Cash on Delivery']
                        .map((x) => ListTile(
                              leading: Radio<String>(value: x, groupRegistry: RadioGroup.maybeOf<String>(context)),
                              title: Text(x),
                              onTap: () => context.read<CheckoutCubit>().payment(x),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                BlocBuilder<CartCubit, CartState>(builder: (_, cart) => CartSummary(cart)),
              ],
            ),
            bottomNavigationBar: BottomActionButton(
              label: 'Place Order',
              icon: Icons.lock_outline,
              isLoading: s.placing,
              onPressed: () => context.read<CheckoutCubit>().place(),
            ),
          ),
        ),
      );
}
