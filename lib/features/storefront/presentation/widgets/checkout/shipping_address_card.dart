import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/entities/address.dart';
import '../../../../../generated/l10n/app_localizations.dart';
import '../../../../../shared/components/app_card.dart';
import '../../../../addresses/addresses.dart';
import '../../cubit/checkout_cubit.dart';
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
    required this.needsPhone,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;
  final Address? selectedAddress;
  final bool hasError;

  /// The selected address has no phone on file, so the order cannot be
  /// placed until one is added (UX-003: COD needs a callable number).
  final bool needsPhone;

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
            // Phone-less address (saved before the field shipped): the
            // courier cannot call, so the order is blocked. The fix is one
            // tap away — the SAME form the address book uses, prefilled
            // with this address (editing keeps its id and default flag).
            if (needsPhone) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone_disabled_outlined,
                      size: 16, color: scheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(l10n.addressPhoneMissing,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final completed = await AddressForm.show(
                      context,
                      initial: selectedAddress,
                      submitLabel: l10n.save,
                    );
                    if (completed != null && context.mounted) {
                      context.read<CheckoutCubit>().selectAddress(completed);
                      // Persist the completion to the address book too, so
                      // the next checkout does not hit the same wall.
                      unawaited(
                          context.read<AddressesCubit>().upsert(completed));
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addPhoneNumber),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
