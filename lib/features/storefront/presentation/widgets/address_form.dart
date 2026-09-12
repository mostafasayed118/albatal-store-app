import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/entities/address.dart';
import '../../../../shared/extensions/build_context_x.dart';

/// A bottom-sheet address form with field-level validation.
///
/// Uses Flutter's [Form] + [GlobalKey<FormState>] + [TextFormField] pattern.
/// This is the canonical Flutter approach: each field owns its validator,
/// the form coordinates validation on submit, and the result is returned
/// via [Navigator.pop] so the caller never sees raw form internals.
final class AddressForm extends StatefulWidget {
  const AddressForm({super.key});

  /// Shows the form in a modal bottom sheet and returns the entered address
  /// on successful validation, or `null` if the user cancels.
  static Future<Address?> show(BuildContext context) async {
    // Let the tapped row's frame finish rendering before pushing the sheet;
    // a slow device can otherwise starve the route's opening frame.
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return null;
    final result = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddressForm(),
    );
    return result;
  }

  @override
  State<AddressForm> createState() => _AddressFormState();
}

final class _AddressFormState extends State<AddressForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(Address(
        // Client-generated v4 UUID; the server treats it as an opaque key
        // (never a timestamp ordering signal).
        id: const Uuid().v4(),
        recipient: _nameCtrl.text.trim(),
        line: _streetCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addNewAddress,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.fullName),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? l10n.nameRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _streetCtrl,
              decoration: InputDecoration(labelText: l10n.streetAddress),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().length < 5)
                  ? l10n.streetAddressRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityCtrl,
              decoration: InputDecoration(labelText: l10n.city),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.cityRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _countryCtrl,
              decoration: InputDecoration(labelText: l10n.country),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.countryRequired : null,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: Text(l10n.continueLabel)),
          ],
        ),
      ),
    );
  }
}
