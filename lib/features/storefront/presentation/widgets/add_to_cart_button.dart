import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/product_details_cubit.dart';
import 'bottom_action_button.dart';

/// Add to cart / out of stock button.
class AddToCartButton extends StatelessWidget {
  const AddToCartButton(
      {super.key, required this.state, required this.l, required this.scheme});
  final DetailsState state;
  final AppLocalizations l;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final p = state.product!;
    return BottomActionButton(
      label: state.inStock ? l.addToCart : l.outOfStock,
      icon: Icons.shopping_bag_outlined,
      backgroundColor: state.inStock ? scheme.secondary : scheme.outline,
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
    );
  }
}
