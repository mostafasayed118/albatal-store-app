import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../cubit/cart_cubit.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/cart_summary.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myCart)),
      body: BlocBuilder<CartCubit, CartState>(
        // Identity on the items list: the cubit always assigns a fresh
        // list on item changes, so same-instance emits (premium-flag
        // mirrors, error-message updates) skip the list rebuild while
        // status transitions and real item edits still rebuild.
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.isPremiumMember != current.isPremiumMember ||
            !identical(previous.items, current.items),
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
            return FeedbackView(
              type: FeedbackViewType.empty,
              icon: Icons.shopping_bag_outlined,
              title: l.cartEmptyTitle,
              // Give the empty cart an exit back into the catalog instead of
              // dead-ending the user.
              actionLabel: l.startShopping,
              onAction: () => context.go(Routes.catalog),
            );
          }
          // Lazily built: a long cart no longer instantiates every
          // tile (plus summary + CTA) on each quantity change — only
          // visible rows build. The trailing footer holds the summary
          // and checkout action.
          return ListView.builder(
            // Directional padding keeps RTL layouts mirrored correctly.
            padding: const EdgeInsetsDirectional.all(16),
            itemCount: s.items.length + 1,
            itemBuilder: (context, index) {
              if (index < s.items.length) {
                return CartItemTile(item: s.items[index]);
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  CartSummary(s),
                  const SizedBox(height: 16),
                  AppButton(
                    label: l.proceedToCheckout,
                    // Points forward in the reading direction (flips under RTL).
                    icon: context.directionalForwardIcon,
                    onPressed: () => context.push(Routes.checkout),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
