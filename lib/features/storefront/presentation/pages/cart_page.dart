import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/feedback_view.dart';
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
          if (s.status == CartStatus.loading) {
            return const FeedbackView(type: FeedbackViewType.loading);
          }
          if (s.status == CartStatus.error) {
            return FeedbackView(
              type: FeedbackViewType.error,
              onAction: () => context.read<CartCubit>().restore(force: true),
            );
          }
          if (s.items.isEmpty) {
            return EmptyStateView(
              icon: Icons.shopping_bag_outlined,
              title: l.cartEmptyTitle,
              // Give the empty cart an exit back into the catalog instead of
              // dead-ending the user.
              actionLabel: l.continueShopping,
              onAction: () => context.go('/catalog'),
            );
          }
          return ListView(
            // Directional padding keeps RTL layouts mirrored correctly.
            padding: const EdgeInsetsDirectional.all(16),
            children: [
              ...s.items.map((i) => CartItemTile(item: i)),
              const SizedBox(height: 16),
              CartSummary(s),
              const SizedBox(height: 16),
              AppButton(
                label: l.proceedToCheckout,
                // Points forward in the reading direction (flips under RTL).
                icon: context.directionalForwardIcon,
                onPressed: () => context.push('/checkout'),
              ),
            ],
          );
        },
      ),
    );
  }
}
