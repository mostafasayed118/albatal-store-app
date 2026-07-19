import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/address.dart';
import '../cubit/addresses_cubit.dart';

class AddressesPage extends StatelessWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.shippingAddresses)),
      body: BlocBuilder<AddressesCubit, AddressesState>(
        builder: (context, s) {
          if (s.status == AddressesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.status == AddressesStatus.failure) {
            return Center(child: Text(s.errorMessage!));
          }
          if (s.addresses.isEmpty) {
            return Center(child: Text(l.noAddressesSaved));
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
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'default', child: Text('Set as default')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
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
          label: Text(l.addAddress)));
  }
}

void _edit(BuildContext context, Address? a) {
  final r = TextEditingController(text: a?.recipient);
  final l = TextEditingController(text: a?.line);
  final c = TextEditingController(text: a?.city);
  final n = TextEditingController(text: a?.country);
  showDialog(
      context: context,
      builder: (d) => AlertDialog(
              title: Text(a == null ? 'Add address' : 'Edit address'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final x in [
                  (r, 'Recipient'),
                  (l, 'Street address'),
                  (c, 'City'),
                  (n, 'Country')
                ])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                          controller: x.$1,
                          decoration: InputDecoration(labelText: x.$2)))
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      if ([r, l, c, n].any((x) => x.text.trim().isEmpty)) {
                        return;
                      }
                      context.read<AddressesCubit>().upsert(Address(
                          id: a?.id ??
                              DateTime.now().microsecondsSinceEpoch.toString(),
                          recipient: r.text.trim(),
                          line: l.text.trim(),
                          city: c.text.trim(),
                          country: n.text.trim(),
                          isDefault: a?.isDefault ?? false));
                      Navigator.pop(d);
                    },
                    child: const Text('Save'))
              ]));
}
