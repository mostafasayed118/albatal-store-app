import 'package:flutter/material.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/admin_catalog.dart';

/// The create/edit form body for [AdminProductEditPage].
///
/// Stateless rendering only: every controller, value and callback is
/// injected, so validation, the category-UUID contract and the submit flow
/// stay with the owning page's state. Returns a [Column] — the page wraps
/// it in the scrolling [ListView].
class AdminProductEditForm extends StatelessWidget {
  const AdminProductEditForm({
    super.key,
    required this.nameCtrl,
    required this.slugCtrl,
    required this.descriptionCtrl,
    required this.compositionCtrl,
    required this.careCtrl,
    required this.originCtrl,
    required this.widthCtrl,
    required this.gsmCtrl,
    required this.priceCtrl,
    required this.minCutCtrl,
    required this.loadingCategories,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.sellByLength,
    required this.onSellByLengthChanged,
    required this.isActive,
    required this.onActiveChanged,
    required this.submitting,
    required this.loadingProduct,
    required this.isCreate,
    required this.onSubmit,
  });

  final TextEditingController nameCtrl;
  final TextEditingController slugCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController compositionCtrl;
  final TextEditingController careCtrl;
  final TextEditingController originCtrl;
  final TextEditingController widthCtrl;
  final TextEditingController gsmCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController minCutCtrl;

  /// While the category list loads, the dropdown is replaced by a spinner.
  final bool loadingCategories;

  /// The admin list (ids + names) — values are category UUIDs, satisfying
  /// the `admin_upsert_product` RPC contract, not display names.
  final List<AdminCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;

  final bool sellByLength;
  final ValueChanged<bool> onSellByLengthChanged;

  final bool isActive;
  final ValueChanged<bool> onActiveChanged;

  /// While submitting or the edited row is loading, the save button is
  /// replaced by a spinner — a blank "edit" form must not save.
  final bool submitting;
  final bool loadingProduct;
  final bool isCreate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameCtrl,
          decoration:
              InputDecoration(labelText: context.l10n.adminNameField),
          validator: (v) => v == null || v.trim().isEmpty
              ? context.l10n.adminRequiredField
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: slugCtrl,
          decoration:
              InputDecoration(labelText: context.l10n.adminSlugField),
          validator: (v) => v == null || v.trim().isEmpty
              ? context.l10n.adminRequiredField
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: descriptionCtrl,
          decoration: InputDecoration(labelText: context.l10n.description),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: compositionCtrl,
          decoration: InputDecoration(labelText: context.l10n.composition),
        ),
        loadingCategories
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator()))
            : DropdownButtonFormField<String>(
                // Values are category UUIDs (the RPC contract); the
                // display label is the human-readable name.
                initialValue: selectedCategoryId,
                decoration:
                    InputDecoration(labelText: context.l10n.category),
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: onCategoryChanged,
                validator: (v) => v == null || v.isEmpty
                    ? context.l10n.adminRequiredField
                    : null,
              ),
        const SizedBox(height: 16),
        TextFormField(
          controller: priceCtrl,
          decoration:
              InputDecoration(labelText: context.l10n.adminBasePrice),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return context.l10n.adminRequiredField;
            }
            if (double.tryParse(v.trim()) == null) {
              return context.l10n.adminInvalidNumber;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        TextFormField(
          controller: careCtrl,
          decoration: InputDecoration(labelText: context.l10n.care),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: originCtrl,
          decoration: InputDecoration(labelText: context.l10n.origin),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widthCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: context.l10n.adminWidthCm),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: gsmCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: context.l10n.adminWeightGsm),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.adminSellByLength),
          subtitle: Text(context.l10n.adminSellByLengthHint),
          value: sellByLength,
          onChanged: onSellByLengthChanged,
        ),
        if (sellByLength) ...[
          TextFormField(
            controller: minCutCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration:
                InputDecoration(labelText: context.l10n.adminMinCutMeters),
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          title: Text(context.l10n.active),
          value: isActive,
          onChanged: onActiveChanged,
        ),
        const SizedBox(height: 24),
        submitting || loadingProduct
            ? const Center(child: CircularProgressIndicator())
            : AppButton(
                label: isCreate
                    ? context.l10n.adminCreateProduct
                    : context.l10n.adminUpdateProduct,
                onPressed: onSubmit,
              ),
      ],
    );
  }
}
