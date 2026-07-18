import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// A bottom-sheet address form with field-level validation.
///
/// Uses Flutter's [Form] + [GlobalKey<FormState>] + [TextFormField] pattern.
/// This is the canonical Flutter approach: each field owns its validator,
/// the form coordinates validation on submit, and the result is returned
/// via [Navigator.pop] so the caller never sees raw form internals.
class AddressForm extends StatefulWidget {
  const AddressForm({super.key});

  /// Shows the form in a modal bottom sheet and returns the entered address
  /// on successful validation, or `null` if the user cancels.
  static Future<Address?> show(BuildContext context) async {
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

class _AddressFormState extends State<AddressForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(Address(
        name: _nameCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.addNewAddress,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _streetCtrl,
              decoration: const InputDecoration(labelText: 'Street address'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Enter a valid street address'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(labelText: 'City'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'City is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone number'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                return digits.length < 7 ? 'Enter a valid phone number' : null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: Text(l.continueLabel)),
          ],
        ),
      ),
    );
  }
}

/// Immutable address value object returned by [AddressForm].
class Address {
  const Address({
    required this.name,
    required this.street,
    required this.city,
    required this.phone,
  });

  final String name, street, city, phone;

  @override
  String toString() => '$name, $street, $city';
}
