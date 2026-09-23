import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/entities/address.dart';
import '../../../../core/utils/phone_validator.dart';
import '../../../../shared/extensions/build_context_x.dart';

/// The ONE address form, shared by both entry points.
///
/// Lives in the addresses feature and is exported through its barrel: the
/// address book and the checkout shipping step edit the same entity, and
/// the audit's cross-feature rule (2026-09-21, P2) says other features
/// import the barrel rather than reaching into a sibling's internals.
///
/// This replaced TWO hand-rolled forms (2026-09-23). The second one — an
/// inline dialog in the address book — had drifted: no phone field, no
/// numeric keyboard, and its own weaker validation, so the same customer
/// data had two different quality bars depending on which screen they
/// happened to use. One form means one set of validators, one set of ARB
/// keys and one behavior to test.
///
/// Uses Flutter's [Form] + [GlobalKey<FormState>] + [TextFormField] pattern:
/// each field owns its validator, the form coordinates validation on submit,
/// and the result is returned via [Navigator.pop] so the caller never sees
/// raw form internals.
final class AddressForm extends StatefulWidget {
  const AddressForm({super.key, this.initial, this.submitLabel});

  /// The address being edited, or `null` for a new one. Prefills every
  /// field and, on save, preserves the identity ([Address.id]) and the
  /// [Address.isDefault] flag — editing must never mint a new id or drop
  /// the default mark.
  final Address? initial;

  /// Overrides the submit button copy: the checkout flow says "Continue"
  /// (it continues to payment), the address book says "Save".
  final String? submitLabel;

  /// Shows the form in a modal bottom sheet and returns the entered address
  /// on successful validation, or `null` if the user cancels.
  static Future<Address?> show(
    BuildContext context, {
    Address? initial,
    String? submitLabel,
  }) async {
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
      builder: (_) => AddressForm(initial: initial, submitLabel: submitLabel),
    );
    return result;
  }

  @override
  State<AddressForm> createState() => _AddressFormState();
}

final class _AddressFormState extends State<AddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initial?.recipient);
  late final _phoneCtrl = TextEditingController(text: widget.initial?.phone);
  late final _streetCtrl = TextEditingController(text: widget.initial?.line);
  late final _cityCtrl = TextEditingController(text: widget.initial?.city);
  late final _countryCtrl =
      TextEditingController(text: widget.initial?.country);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(Address(
        // Client-generated v4 UUID for new rows; the server treats it as an
        // opaque key (never a timestamp ordering signal). An edit keeps the
        // id it came in with.
        id: widget.initial?.id ?? const Uuid().v4(),
        recipient: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        line: _streetCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        isDefault: widget.initial?.isDefault ?? false,
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
            Text(widget.initial == null ? l10n.addNewAddress : l10n.editAddress,
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
            // Phone sits right after the name: it is the courier's primary
            // contact for COD hand-off (UX-003), so it leads the address
            // fields. Validated by the shared Egyptian-mobile rule.
            TextFormField(
              controller: _phoneCtrl,
              decoration: InputDecoration(labelText: l10n.phoneLabel),
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  phoneValidator(v, invalidMessage: l10n.phoneInvalid),
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
            FilledButton(
                onPressed: _submit,
                child: Text(widget.submitLabel ?? l10n.continueLabel)),
          ],
        ),
      ),
    );
  }
}
