import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/entities/address.dart';
import '../../../../../generated/l10n/app_localizations.dart';
import '../../../../../shared/components/app_card.dart';
import '../../../../addresses/presentation/cubit/addresses_cubit.dart';
import '../../cubit/checkout_cubit.dart';
import '../address_form.dart';
import '../address_picker.dart';

/// Shipping address card — extracted verbatim from `checkout_page.dart`
/// (was private `_ShippingAddressCard`): same tokens, same children,
/// same behavior.
final class CheckoutShippingAddressCard extends StatelessWidget {
  const CheckoutShippingAddressCard({
    super.key,
    required this.l10n,
    required this.scheme,
    required this.selectedAddress,
    required this.hasError,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;
  final Address? selectedAddress;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shippingAddress,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            AddressPicker(
              selectedAddress: selectedAddress,
              onSelect: (a) => context.read<CheckoutCubit>().selectAddress(a),
              onAddNew: () async {
                final address = await AddressForm.show(context);
                if (address != null && context.mounted) {
                  context.read<CheckoutCubit>().selectAddress(address);
                  // Persist to the address book too: previously the new
                  // address was only selected and vanished on restart
                  // (live-found 2026-09-03).
                  unawaited(context.read<AddressesCubit>().upsert(address));
                }
              },
              l: l10n,
              scheme: scheme,
              hasError: hasError,
            ),
            if (hasError) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: scheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(l10n.validationSelectAddress,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
