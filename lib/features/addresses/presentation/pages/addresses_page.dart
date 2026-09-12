import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/address.dart';
import '../cubit/addresses_cubit.dart';

final class AddressesPage extends StatelessWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
        appBar: AppBar(title: Text(l10n.shippingAddresses)),
        body: BlocBuilder<AddressesCubit, AddressesState>(
          builder: (context, s) {
            if (s.status == AddressesStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.status == AddressesStatus.failure) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.errorMessage ?? l10n.errorTitle),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          context.read<AddressesCubit>().load(force: true),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            }
            if (s.addresses.isEmpty) {
              return Center(child: Text(l10n.noAddressesSaved));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: s.addresses.map((a) {
                return Card(
                  child: ListTile(
                    leading: Icon(
                        a.isDefault ? Icons.home : Icons.location_on_outlined),
                    title: Text(a.recipient),
                    subtitle: Text('${a.line}, ${a.city}, ${a.country}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        final c = context.read<AddressesCubit>();
                        if (v == 'default') c.setDefault(a.id);
                        if (v == 'delete') c.remove(a.id);
                        if (v == 'edit') _edit(context, a);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'default', child: Text(l10n.setAsDefault)),
                        PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                        PopupMenuItem(
                            value: 'delete', child: Text(l10n.delete)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: Text(l10n.addAddress)));
  }
}

Future<void> _edit(BuildContext context, Address? a) async {
  // Let the tapped row's frame finish rendering before pushing the dialog;
  // a slow device can otherwise starve the route's opening frame.
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;
  final recipientCtrl = TextEditingController(text: a?.recipient);
  final streetCtrl = TextEditingController(text: a?.line);
  final cityCtrl = TextEditingController(text: a?.city);
  final countryCtrl = TextEditingController(text: a?.country);
  try {
    await showDialog<void>(
      context: context,
      builder: (d) {
        var submitted = false;
        final loc = d.l10n;
        final fields = [
          (recipientCtrl, loc.recipientName),
          (streetCtrl, loc.streetAddress),
          (cityCtrl, loc.city),
          (countryCtrl, loc.country),
        ];
        return StatefulBuilder(
          builder: (d, setState) => AlertDialog(
            title: Text(a == null ? loc.addAddress : loc.editAddress),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: field.$1,
                        decoration: InputDecoration(
                          labelText: field.$2,
                          errorText: submitted && field.$1.text.trim().isEmpty
                              ? loc.fieldRequired
                              : null,
                        ),
                        onChanged: (_) {
                          if (submitted) setState(() {});
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () {
                  if (fields.any((field) => field.$1.text.trim().isEmpty)) {
                    setState(() => submitted = true);
                    return;
                  }
                  context.read<AddressesCubit>().upsert(Address(
                        // Client-generated v4 UUID; the server treats it as
                        // an opaque key (never a timestamp ordering signal).
                        id: a?.id ?? const Uuid().v4(),
                        recipient: recipientCtrl.text.trim(),
                        line: streetCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        country: countryCtrl.text.trim(),
                        isDefault: a?.isDefault ?? false,
                      ));
                  Navigator.pop(d);
                },
                child: Text(loc.save),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    recipientCtrl.dispose();
    streetCtrl.dispose();
    cityCtrl.dispose();
    countryCtrl.dispose();
  }
}
