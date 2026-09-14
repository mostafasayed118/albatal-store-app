import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/services/logger.dart';
import '../../domain/entities/admin_catalog.dart';
import '../../domain/repositories/admin_repository.dart';

/// Admin product create/edit — calls [AdminRepository.adminUpsertProduct].
///
/// All copy on this form is admin-only, intentionally unlocalized (no ARB
/// keys; the storefront stays localized).
///
/// The repository is constructor-injected (audit P1); the router resolves
/// it at the composition root.
class AdminProductEditPage extends StatefulWidget {
  const AdminProductEditPage({
    super.key,
    this.productId,
    this.initialData,
    required this.repository,
  });

  /// When non-null, editing existing product; null means create.
  final String? productId;
  final Map<String, dynamic>? initialData;
  final AdminRepository repository;

  @override
  State<AdminProductEditPage> createState() => _AdminProductEditPageState();
}

class _AdminProductEditPageState extends State<AdminProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _compositionCtrl;
  late final TextEditingController _careCtrl;
  late final TextEditingController _originCtrl;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _gsmCtrl;
  late final TextEditingController _minCutCtrl;
  bool _sellByLength = false;
  late final TextEditingController _priceCtrl;
  bool _isActive = true;

  /// The product's category, as the `admin_upsert_product` RPC contract
  /// requires: `categories.id` (a UUID) — NOT the display name.
  String? _selectedCategoryId;
  List<AdminCategory> _categories = const [];
  bool _loadingCategories = true;
  bool _submitting = false;

  /// While the product row is being fetched for an edit, the form is
  /// disabled — a blank "edit" form invites saving an accidental wipe.
  bool _loadingProduct = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameCtrl = TextEditingController(text: safeString(d, 'name'));
    _slugCtrl = TextEditingController(text: safeString(d, 'slug'));
    _descriptionCtrl =
        TextEditingController(text: safeString(d, 'description'));
    _compositionCtrl =
        TextEditingController(text: safeString(d, 'composition'));
    _careCtrl = TextEditingController(text: safeString(d, 'care'));
    _originCtrl = TextEditingController(text: safeString(d, 'origin'));
    _widthCtrl = TextEditingController(text: safeString(d, 'width_cm'));
    _gsmCtrl = TextEditingController(text: safeString(d, 'gsm'));
    _minCutCtrl = TextEditingController(text: safeString(d, 'min_cut_meters'));
    _sellByLength = safeString(d, 'sell_by_length') == 'true';
    _priceCtrl = TextEditingController(text: _minorToInput(d?['base_price']));
    _isActive = safeBool(d, 'is_active', fallback: true);
    _selectedCategoryId = d?['category_id'] as String?;
    if (widget.productId != null && d == null) {
      // Reached by id only (route or picker) — load the row so the
      // form prefills instead of presenting a blank "edit" form.
      _loadProduct();
    }
    _loadCategories();
  }

  Future<void> _loadProduct() async {
    setState(() => _loadingProduct = true);
    // Single-row fetch (audit 2026-09-13): the page previously loaded
    // the whole bounded products list and linear-scanned for the id.
    final result = await widget.repository.getProductById(widget.productId!);
    if (!mounted) return;
    String? failureMessage;
    AdminProduct? product;
    switch (result) {
      case Success(:final value):
        product = value;
      case Failure(:final error):
        failureMessage = error.message;
    }
    if (!mounted) return;
    if (product == null) {
      showFloatingError(context, failureMessage ?? 'Product not found');
      setState(() => _loadingProduct = false);
      return;
    }
    _nameCtrl.text = product.name;
    _slugCtrl.text = product.slug;
    _descriptionCtrl.text = product.description ?? '';
    _compositionCtrl.text = product.composition ?? '';
    _careCtrl.text = product.care ?? '';
    _originCtrl.text = product.origin ?? '';
    _widthCtrl.text = product.widthCm?.toString() ?? '';
    _gsmCtrl.text = product.gsm?.toString() ?? '';
    _minCutCtrl.text = product.minCutMeters?.toString() ?? '';
    _sellByLength = product.sellByLength;
    _priceCtrl.text =
        product.basePrice == 0 ? '' : _minorToInput(product.basePrice);
    _isActive = product.isActive;
    _selectedCategoryId = product.categoryId;
    setState(() => _loadingProduct = false);
  }

  /// Rows carry INTEGER minor units (migration 001) while the form edits
  /// major EGP ("1890", or "1290.50"); prefill converts via [Money] so
  /// the admin never sees raw cents in the field (audit 2026-09-14).
  static String _minorToInput(Object? minorRaw) =>
      minorRaw is num && minorRaw > 0
          ? Money(minorRaw.round()).format(symbol: '')
          : '';

  Future<void> _loadCategories() async {
    try {
      // The admin list (ids + names, including inactive) — not the
      // storefront name list, which cannot satisfy the RPC's UUID contract.
      final result = await widget.repository.getAllCategories();
      if (!mounted) return;
      result.when(
        success: (categories) {
          setState(() {
            _categories = categories;
            _loadingCategories = false;
            final ids = categories.map((c) => c.id).toSet();
            if (_selectedCategoryId != null &&
                !ids.contains(_selectedCategoryId)) {
              // The product's category vanished from the visible list
              // (e.g. deactivated): keep it selectable instead of
              // silently rewriting the product's value on save.
              _categories = [
                ..._categories,
                AdminCategory(
                  id: _selectedCategoryId!,
                  name: _selectedCategoryId!,
                  isActive: true,
                ),
              ];
            } else if (_selectedCategoryId == null && _categories.isNotEmpty) {
              _selectedCategoryId = _categories.first.id;
            }
          });
        },
        failure: (e) {
          setState(() {
            _loadingCategories = false;
            if (_selectedCategoryId != null) {
              // Degraded mode: keep the current category selectable so
              // an edit can still save; the id stands in for the name.
              _categories = [
                AdminCategory(
                  id: _selectedCategoryId!,
                  name: _selectedCategoryId!,
                  isActive: true,
                ),
              ];
            }
          });
        },
      );
    } catch (e) {
      Log.w('Admin categories load failed: $e');
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descriptionCtrl.dispose();
    _compositionCtrl.dispose();
    _careCtrl.dispose();
    _originCtrl.dispose();
    _widthCtrl.dispose();
    _gsmCtrl.dispose();
    _minCutCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loadingProduct || !_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      showFloatingError(context, 'Please select a category');
      return;
    }
    // The form collects EGP text; [Money.tryParseMajor] is the single
    // ×100 conversion point into minor units (audit 2026-09-14).
    final priceMinor = Money.tryParseMajor(_priceCtrl.text.trim());
    if (priceMinor == null) {
      // tryParseMajor rejects negatives as malformed input; keep the
      // dedicated message so the admin sees the real problem (audit
      // 2026-09-14 regression: '-50' must not read as 'Invalid price').
      showFloatingError(
        context,
        _priceCtrl.text.trim().startsWith('-')
            ? 'Price cannot be negative'
            : 'Invalid price',
      );
      return;
    }
    if (priceMinor.minorUnits <= 0) {
      // The DB enforces this too (001: base_price > 0), but failing here
      // gives an inline message instead of a generic save failure.
      showFloatingError(context, 'Price cannot be negative');
      return;
    }
    setState(() => _submitting = true);
    final result = await widget.repository.adminUpsertProduct(
      id: widget.productId,
      name: _nameCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      composition: _compositionCtrl.text.trim().isEmpty
          ? null
          : _compositionCtrl.text.trim(),
      care: _careCtrl.text.trim().isEmpty ? null : _careCtrl.text.trim(),
      origin: _originCtrl.text.trim().isEmpty ? null : _originCtrl.text.trim(),
      widthCm: int.tryParse(_widthCtrl.text.trim()),
      gsm: int.tryParse(_gsmCtrl.text.trim()),
      sellByLength: _sellByLength,
      minCutMeters: double.tryParse(_minCutCtrl.text.trim()),
      categoryId: _selectedCategoryId!,
      basePrice: priceMinor.minorUnits.toDouble(),
      isActive: _isActive,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      success: (_) {
        showConfirmation(
          context,
          widget.productId == null ? 'Product created' : 'Product updated',
        );
        context.pop(true);
      },
      failure: (error) {
        // Repository messages are fixed, user-facing strings — the raw
        // exception never reaches the UI (leak scrubbed with the Result
        // migration).
        showFloatingError(context, error.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The form was previously titled "Products" in both modes —
        // indistinguishable from the list page in the back stack.
        title: Text(widget.productId == null ? 'New Product' : 'Edit Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _slugCtrl,
              decoration: const InputDecoration(labelText: 'Slug'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _compositionCtrl,
              decoration: const InputDecoration(labelText: 'Composition'),
            ),
            _loadingCategories
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator()))
                : DropdownButtonFormField<String>(
                    // Values are category UUIDs (the RPC contract); the
                    // display label is the human-readable name.
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: 'Base Price (EGP)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                // Syntax check only: a leading '-' is syntactically valid
                // but rejected semantically by _submit with the dedicated
                // 'Price cannot be negative' message (audit 2026-09-14).
                final text = v.trim();
                final magnitude =
                    text.startsWith('-') ? text.substring(1) : text;
                if (Money.tryParseMajor(magnitude) == null) {
                  return 'Invalid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            TextFormField(
              controller: _careCtrl,
              decoration: const InputDecoration(labelText: 'Care'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _originCtrl,
              decoration: const InputDecoration(labelText: 'Origin'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _widthCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Width (cm)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _gsmCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Weight (GSM)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sell by length (per meter)'),
              subtitle: const Text(
                  'Shoppers pick a custom cut length in 0.5 m steps'),
              value: _sellByLength,
              onChanged: (v) => setState(() => _sellByLength = v),
            ),
            if (_sellByLength) ...[
              TextFormField(
                controller: _minCutCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Minimum cut (meters)'),
              ),
              const SizedBox(height: 16),
            ],
            SwitchListTile(
              title: const Text('Active'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 24),
            _submitting || _loadingProduct
                ? const Center(child: CircularProgressIndicator())
                : AppButton(
                    label: widget.productId == null
                        ? 'Create Product'
                        : 'Update Product',
                    onPressed: _submit,
                  ),
          ],
        ),
      ),
    );
  }
}
