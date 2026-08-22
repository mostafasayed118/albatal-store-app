import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/product_details_cubit.dart';

/// Stitch details CTA bar (spec §4/§5): a 72dp surface bar pinned at
/// `bottomNavigationBar` holding one gold [FilledButton].
///
/// Token map: fill `scheme.secondary` #904D00, `controlRadius` 8,
/// EdgeInsetsDirectional.all(16) padding, label `labelLarge`.
/// The button calls [CartCubit.add] with the selected variant.
class AddToCartButton extends StatelessWidget {
  const AddToCartButton(
      {super.key, required this.state, required this.l, required this.scheme});
  final DetailsState state;
  final AppLocalizations l;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final p = state.product!;
    return Container(
      height: 72,
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(color: scheme.surface),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor:
              state.inStock ? scheme.secondary : scheme.outline,
          foregroundColor: state.inStock
              ? scheme.onSecondary
              : scheme.onSurfaceVariant,
          // 72dp bar − 2×16dp padding = 40dp button height.
          minimumSize: const Size.fromHeight(40),
          shape: const RoundedRectangleBorder(
              borderRadius: AppTheme.controlRadius),
        ),
        onPressed: state.inStock
            ? () {
                context.read<CartCubit>().add(p,
                    color: state.color,
                    length: state.length,
                    quantity: state.quantity);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.addedToCart)));
              }
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_bag_outlined),
            const SizedBox(width: 8),
            Text(state.inStock ? l.addToCart : l.outOfStock),
          ],
        ),
      ),
    );
  }
}
