import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../cubit/recently_viewed_cubit.dart';
import 'related_card.dart';

/// Horizontal "Recently viewed" strip for the home page (#3).
///
/// Renders nothing until the shopper has actually viewed a product —
/// an empty section header would be dead chrome.
final class RecentlyViewedStrip extends StatelessWidget {
  const RecentlyViewedStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecentlyViewedCubit, RecentlyViewedState>(
      builder: (context, state) {
        if (state.products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.recentlyViewed,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final product = state.products[i];
                  return RelatedCard(
                    product: product,
                    onTap: () => context.push(Routes.product(product.id)),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
