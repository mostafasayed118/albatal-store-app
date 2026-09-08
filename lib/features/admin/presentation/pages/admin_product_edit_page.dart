import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/entities/admin_catalog.dart';
import '../../domain/repositories/admin_repository.dart';

/// Admin product create/edit — calls [AdminRepository.adminUpsertProduct].
class AdminProductEditPage extends StatefulWidget {
  const AdminProductEditPage({
    super.key,
    this.productId,
    this.initialData,
  });

  /// When non-null, editing existing product; null means create.
  final String? productId;
  final Map<String, dynamic>? initialData;

  @override
  State<AdminProductEditPage> createState() => _AdminProductEditPageState();
}

class _AdminProductEditPageState extends State<AdminProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _compositionCtrl;
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
    final price = d?['base_price'];
    _priceCtrl = TextEditingController(
      text: price == null ? '' : price.toString(),
    );
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
    final result = await getIt<AdminRepository>().getAllProducts();
    if (!mounted) return;
    AdminProduct? product;
    if (result case Success(:final value)) {
      for (final p in value) {
        if (p.id == widget.productId) {
          product = p;
          break;
        }
      }
    }
    if (!mounted) return;
    if (product == null) {
      showFloatingError(context, 'Product not found');
      setState(() => _loadingProduct = false);
      return;
    }
    _nameCtrl.text = product.name;
    _slugCtrl.text = product.slug;
    _descriptionCtrl.text = product.description ?? '';
    _compositionCtrl.text = product.composition ?? '';
    _priceCtrl.text =
        product.basePrice == 0 ? '' : _trimTrailingZeros(product.basePrice);
    _isActive = product.isActive;
    _selectedCategoryId = product.categoryId;
    setState(() => _loadingProduct = false);
  }

  /// Prices render whole-EGP style across the admin surfaces (1890, not
  /// 1890.0); keep the form consistent when prefilling from the row.
  static String _trimTrailingZeros(double value) {
    final s = value.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  Future<void> _loadCategories() async {
    try {
      // The admin list (ids + names, including inactive) — not the
      // storefront name list, which cannot satisfy the RPC's UUID contract.
      final result = await getIt<AdminRepository>().getAllCategories();
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
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descriptionCtrl.dispose();
    _compositionCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loadingProduct || !_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      showFloatingError(context, 'Please select a category');
      return;
    }
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null) {
      showFloatingError(context, 'Invalid price');
      return;
    }
    if (price <= 0) {
      // The DB enforces this too (001: base_price > 0), but failing here
      // gives an inline message instead of a generic save failure.
      showFloatingError(context, 'Price cannot be negative');
      return;
    }
    setState(() => _submitting = true);
    final result = await getIt<AdminRepository>().adminUpsertProduct(
      id: widget.productId,
      name: _nameCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      composition: _compositionCtrl.text.trim().isEmpty
          ? null
          : _compositionCtrl.text.trim(),
      categoryId: _selectedCategoryId!,
      basePrice: price,
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
            const SizedBox(height: 16),
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
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
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
