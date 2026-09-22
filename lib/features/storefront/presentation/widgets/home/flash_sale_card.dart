import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/entities/product.dart';
import '../../../../../shared/components/feedback.dart';
import '../../../../../shared/components/stitch/stitch_flash_sale_card.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../../shared/routing/app_routes.dart';
import '../../cubit/cart_cubit.dart';

/// Flash-sale card bound to [CatalogCubit.flashCountdown]: the 1Hz
/// countdown re-renders this subtree only, and shows nothing while the
/// stream is quiet (no deadline or no active sale).
///
/// Extracted from `home_page.dart` verbatim (was private `_FlashSaleCard`).
final class HomeFlashSaleCard extends StatelessWidget {
  const HomeFlashSaleCard({
    super.key,
    required this.product,
    required this.discountLabel,
    required this.countdown,
  });

  final Product product;
  final String discountLabel;
  final Stream<Duration> countdown;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: countdown,
      builder: (context, snapshot) {
        final remaining =
            (snapshot.data != null && snapshot.data! > Duration.zero)
                ? snapshot.data
                : null;
        return StitchFlashSaleCard(
          product: product,
          discountLabel: discountLabel,
          remaining: remaining,
          onAdd: () {
            context.read<CartCubit>().add(product);
            // Acknowledge the add — the flash-sale card lives far from
            // the cart badge, and a silent tap reads as "did that even
            // work?".
            showConfirmation(context, context.l10n.addedToCart);
          },
          onTap: () => context.push(Routes.product(product.id)),
        );
      },
    );
  }
}
