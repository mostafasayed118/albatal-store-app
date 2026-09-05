import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../storefront/domain/repositories/catalog_repository.dart';
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
  String? _selectedCategory;
  List<String> _categories = const [];
  bool _loadingCategories = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameCtrl = TextEditingController(text: d?['name'] as String? ?? '');
    _slugCtrl = TextEditingController(text: d?['slug'] as String? ?? '');
    _descriptionCtrl =
        TextEditingController(text: d?['description'] as String? ?? '');
    _compositionCtrl =
        TextEditingController(text: d?['composition'] as String? ?? '');
    final price = d?['base_price'];
    _priceCtrl = TextEditingController(
      text: price == null ? '' : price.toString(),
    );
    _isActive = d?['is_active'] as bool? ?? true;
    _selectedCategory =
        d?['category_id'] as String? ?? d?['category'] as String?;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final repo = getIt<CatalogRepository>();
      final result = await repo.fetchCategories();
      if (!mounted) return;
      result.when(
        success: (cats) {
          setState(() {
            _categories = cats;
            _loadingCategories = false;
            if (_selectedCategory != null &&
                !_categories.contains(_selectedCategory)) {
              // Keep existing value even if not in list (e.g. category id).
              _categories = [..._categories, _selectedCategory!];
            } else if (_selectedCategory == null && _categories.isNotEmpty) {
              _selectedCategory = _categories.first;
            }
          });
        },
        failure: (e) {
          setState(() {
            _loadingCategories = false;
            _categories =
                _selectedCategory != null ? [_selectedCategory!] : const [];
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid price')),
      );
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
      categoryId: _selectedCategory!,
      basePrice: price,
      isActive: _isActive,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.productId == null
                  ? 'Product created'
                  : 'Product updated')),
        );
        context.pop(true);
      },
      failure: (error) {
        // Repository messages are fixed, user-facing strings — the raw
        // exception never reaches the UI (leak scrubbed with the Result
        // migration).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? l.products : l.products),
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
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
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
            _submitting
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
