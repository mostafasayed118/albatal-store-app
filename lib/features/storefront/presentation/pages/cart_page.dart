import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/cart_summary.dart';
import '../widgets/empty_state_view.dart';

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
              ...s.items.map((i) => CartItemTile(item: i)),
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
