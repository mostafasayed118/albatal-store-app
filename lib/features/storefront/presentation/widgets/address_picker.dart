import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/address.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../addresses/addresses.dart';
import 'address_tile.dart';
import 'empty_address_card.dart';

/// Radio-style address picker from saved addresses.
class AddressPicker extends StatelessWidget {
  const AddressPicker({
    super.key,
    required this.selectedAddress,
    required this.onSelect,
    required this.onAddNew,
    required this.l,
    required this.scheme,
    required this.hasError,
  });
  final Address? selectedAddress;
  final ValueChanged<Address> onSelect;
  final VoidCallback onAddNew;
  final AppLocalizations l;
  final ColorScheme scheme;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddressesCubit, AddressesState>(
      builder: (context, state) {
        // A failed read with an empty book used to be indistinguishable
        // from "no addresses": surface it with a retry instead of the
        // empty card. With saved addresses present, keep the list visible.
        if (state.status == AddressesStatus.failure &&
            state.addresses.isEmpty) {
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.errorTitle,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.read<AddressesCubit>().load(force: true),
                  child: Text(l.retry),
                ),
              ],
            ),
          );
        }
        if (state.addresses.isEmpty) {
          return EmptyAddressCard(onAddNew: onAddNew, l: l, scheme: scheme);
        }
        return Column(
          children: [
            ...state.addresses.map((a) => AddressTile(
                  address: a,
                  isSelected: selectedAddress?.id == a.id,
                  hasError: hasError,
                  l: l,
                  scheme: scheme,
                  onTap: () => onSelect(a),
                )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddNew,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.addNewAddress),
            ),
          ],
        );
      },
    );
  }
}
