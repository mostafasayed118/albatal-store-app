import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/cart_cubit.dart';
import '../cubit/products_data.dart';
import '../widgets/cart_summary.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Cart')),
        body: BlocBuilder<CartCubit, CartState>(
          builder: (context, s) {
            if (s.items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 64),
                    SizedBox(height: 12),
                    Text('Your cart is waiting for something exquisite.'),
                  ],
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...s.items.map(
                  (i) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            color: Color(i.product.imageColor),
                            child: const Icon(Icons.texture, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.product.name, style: Theme.of(context).textTheme.titleSmall),
                                Text('${i.color} · ${i.length}'),
                                Text(money(i.product.price * i.quantity)),
                                Row(
                                  children: [
                                    IconButton(onPressed: () => context.read<CartCubit>().update(i.key, i.quantity - 1), icon: const Icon(Icons.remove)),
                                    Text('${i.quantity}'),
                                    IconButton(onPressed: () => context.read<CartCubit>().update(i.key, i.quantity + 1), icon: const Icon(Icons.add)),
                                    TextButton(
                                      onPressed: () => context.read<CartCubit>().remove(i.key),
                                      child: const Text('Remove', style: TextStyle(color: Color(0xFFBA1A1A))),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CartSummary(s),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.push('/checkout'), child: const Text('Proceed to Checkout')),
              ],
            );
          },
        ),
      );
}
