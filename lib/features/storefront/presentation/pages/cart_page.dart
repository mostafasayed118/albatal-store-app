import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/products_data.dart';
import '../widgets/cart_summary.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/product_image_placeholder.dart';
import '../widgets/quantity_stepper.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myCart)),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, s) {
          if (s.items.isEmpty) {
            return EmptyStateView(
              icon: Icons.shopping_bag_outlined,
              title: l.cartEmptyTitle,
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
                        ProductImagePlaceholder(
                          imageColor: i.product.imageColor,
                          imageAsset: i.product.imageAsset,
                          constraints: const BoxConstraints.tightFor(
                              width: 72, height: 72),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.product.name,
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              Text('${i.color} · ${i.length}'),
                              Text(money(i.product.price * i.quantity)),
                              QuantityStepper(
                                quantity: i.quantity,
                                onChanged: (q) => context
                                    .read<CartCubit>()
                                    .update(i.key, q),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.read<CartCubit>().remove(i.key),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).colorScheme.error,
                                ),
                                child: Text(l.remove),
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
              AppButton(
                label: l.proceedToCheckout,
                icon: Icons.arrow_forward,
                onPressed: () => context.push('/checkout'),
              ),
            ],
          );
        },
      ),
    );
  }
}
