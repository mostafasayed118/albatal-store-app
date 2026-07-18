import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/address.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../addresses/presentation/cubit/addresses_cubit.dart';

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
        if (state.addresses.isEmpty) {
          return _EmptyAddress(l: l, onAddNew: onAddNew, scheme: scheme);
        }
        return Column(
          children: [
            ...state.addresses.map((a) => _AddressTile(
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

class _EmptyAddress extends StatelessWidget {
  const _EmptyAddress(
      {required this.l, required this.onAddNew, required this.scheme});
  final AppLocalizations l;
  final VoidCallback onAddNew;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.location_off_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 8),
            Text(l.noAddressesSaved,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAddNew,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.addAddress),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.isSelected,
    required this.hasError,
    required this.l,
    required this.scheme,
    required this.onTap,
  });

  final Address address;
  final bool isSelected, hasError;
  final AppLocalizations l;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? scheme.primaryContainer.withValues(alpha: .3) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? scheme.primary
              : hasError
                  ? scheme.error
                  : scheme.outline.withValues(alpha: .3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          address.isDefault ? Icons.home : Icons.location_on_outlined,
          color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(address.recipient,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (address.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l.defaultLabel,
                    style: TextStyle(fontSize: 10, color: scheme.primary)),
              ),
          ],
        ),
        subtitle: Text('${address.line}, ${address.city}, ${address.country}'),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : Icon(Icons.radio_button_unchecked, color: scheme.outline),
        onTap: onTap,
      ),
    );
  }
}
