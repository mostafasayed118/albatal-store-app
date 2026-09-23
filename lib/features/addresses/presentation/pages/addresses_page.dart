import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/phone_validator.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../domain/entities/address.dart';
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

Future<void> _edit(BuildContext context, Address? a) async {
  // Let the tapped row's frame finish rendering before pushing the dialog;
  // a slow device can otherwise starve the route's opening frame.
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _AddressDialog(
      initial: a,
      // The cubit is read with the PAGE's context on purpose: showDialog
      // pushes onto the root navigator, whose dialog routes are siblings
      // of `home` — a dialog context cannot find the page's BlocProvider.
      onSave: (addr) => context.read<AddressesCubit>().upsert(addr),
    ),
  );
}

/// The address-book add/edit dialog as a real widget.
///
/// Extracted from an inline `StatefulBuilder` when the phone field shipped
/// (UX-003). The extraction is not cosmetic: the old version created the
/// controllers in `_edit` and disposed them in a `finally` the moment
/// `showDialog`'s future resolved — that happens at POP time, while the
/// dialog's exit animation is still rebuilding its TextFields, so the
/// widgets kept touching disposed controllers (`A TextEditingController
/// was used after being disposed`, caught live by the phone-field widget
/// test — the first test ever to save this dialog successfully). Owning
/// the controllers in a [State] and disposing in [dispose] is the
/// canonical pattern (same as `AddressForm`).
class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.initial, required this.onSave});

  /// The address being edited, or `null` for the add flow (which also
  /// drives the title copy).
  final Address? initial;

  /// Called with the validated address on Save, wired by [_edit] to the
  /// addresses cubit.
  final ValueChanged<Address> onSave;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final _recipientCtrl =
      TextEditingController(text: widget.initial?.recipient);
  late final _phoneCtrl = TextEditingController(text: widget.initial?.phone);
  late final _streetCtrl = TextEditingController(text: widget.initial?.line);
  late final _cityCtrl = TextEditingController(text: widget.initial?.city);
  late final _countryCtrl =
      TextEditingController(text: widget.initial?.country);
  var _submitted = false;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_fields.any((field) => _errorFor(field) != null)) {
      setState(() => _submitted = true);
      return;
    }
    widget.onSave(Address(
      // Client-generated v4 UUID; the server treats it as an opaque key
      // (never a timestamp ordering signal).
      id: widget.initial?.id ?? const Uuid().v4(),
      recipient: _recipientCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      line: _streetCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      isDefault: widget.initial?.isDefault ?? false,
    ));
    Navigator.of(context).pop();
  }

  // Per-field validation: each entry carries an optional validator over
  // the trimmed value; a `null` validator falls back to the required
  // check (the pre-phone behavior, kept verbatim for the four text
  // fields). The phone field validates via the shared Egyptian-mobile
  // rule (UX-003) and gets a numeric keyboard with telephone autofill.
  List<
      (
        TextEditingController,
        String,
        TextInputType?,
        String? Function(String)?
      )> get _fields {
    final loc = context.l10n;
    return [
      (_recipientCtrl, loc.recipientName, null, null),
      (
        _phoneCtrl,
        loc.phoneLabel,
        TextInputType.phone,
        (v) => phoneValidator(v, invalidMessage: loc.phoneInvalid),
      ),
      (_streetCtrl, loc.streetAddress, null, null),
      (_cityCtrl, loc.city, null, null),
      (_countryCtrl, loc.country, null, null),
    ];
  }

  String? _errorFor(
      (
        TextEditingController,
        String,
        TextInputType?,
        String? Function(String)?
      ) field) {
    final validator = field.$4;
    if (validator != null) return validator(field.$1.text.trim());
    return field.$1.text.trim().isEmpty ? context.l10n.fieldRequired : null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final fields = _fields;
    return AlertDialog(
      title: Text(widget.initial == null ? loc.addAddress : loc.editAddress),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: field.$1,
                  keyboardType: field.$3,
                  autofillHints: field.$3 == TextInputType.phone
                      ? const [AutofillHints.telephoneNumber]
                      : null,
                  decoration: InputDecoration(
                    labelText: field.$2,
                    errorText: _submitted ? _errorFor(field) : null,
                  ),
                  onChanged: (_) {
                    if (_submitted) setState(() {});
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(loc.save),
        ),
      ],
    );
  }
}
