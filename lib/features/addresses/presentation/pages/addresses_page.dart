import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../domain/entities/address.dart';
import '../cubit/addresses_cubit.dart';
import '../widgets/address_form.dart';

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
              return const FeedbackView(type: FeedbackViewType.loading);
            }
            if (s.status == AddressesStatus.failure) {
              return FeedbackView(
                type: FeedbackViewType.error,
                // Code-first copy (audit 2026-09-19, sweep part 32).
                body: failureText(l10n,
                    code: s.errorCode,
                    message: s.errorMessage,
                    fallback: l10n.errorTitle),
                onAction: () =>
                    context.read<AddressesCubit>().load(force: true),
              );
            }
            if (s.addresses.isEmpty) {
              // No CTA override: the add-address FAB already carries the
              // addAddress label on this screen.
              return FeedbackView(
                type: FeedbackViewType.empty,
                icon: Icons.location_on_outlined,
                body: l10n.noAddressesSaved,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: s.addresses.length,
              itemBuilder: (context, index) {
                final a = s.addresses[index];
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
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: Text(l10n.addAddress)));
  }
}

/// Opens the shared address form for a new (`null`) or existing address.
///
/// The address book used to own a second, hand-rolled dialog (audit
/// UX-003/UX-014): no phone field, no numeric keyboard, weaker validation.
/// It is now the same [AddressForm] the checkout flow uses — one form, one
/// set of validators, one set of ARB keys.
Future<void> _edit(BuildContext context, Address? a) async {
  final updated = await AddressForm.show(
    context,
    initial: a,
    // The address book saves; the checkout flow continues to payment.
    submitLabel: context.l10n.save,
  );
  if (updated != null && context.mounted) {
    await context.read<AddressesCubit>().upsert(updated);
  }
}
