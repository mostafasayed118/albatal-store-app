import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/utils/safe_parse.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../domain/entities/admin_catalog.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/product_edit_form.dart';
import '../widgets/product_edit_loaders.dart';

/// Admin product create/edit — calls [AdminRepository.adminUpsertProduct].
///
/// Copy on this form is localized like the storefront (owner decision, part 34).
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
    final price = d?['base_price'];
    final priceMinor = price is num && price >= 0 ? price.toInt() : 0;
    _priceCtrl = TextEditingController(
      text: priceMinor == 0 ? '' : Money(priceMinor).format(symbol: ''),
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
    // Single-row fetch (audit 2026-09-13): the page previously loaded
    // the whole bounded products list and linear-scanned for the id.
    final loaded = await fetchProductForEdit(
      repository: widget.repository,
      productId: widget.productId!,
    );
    if (!mounted) return;
    final product = loaded.product;
    if (product == null) {
      showFloatingError(
        context,
        failureText(context.l10n,
            code: loaded.failureCode,
            message: loaded.failureMessage,
            fallback: context.l10n.adminProductNotFound),
      );
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
    _priceCtrl.text = product.basePrice.minorUnits == 0
        ? ''
        : product.basePrice.format(symbol: '');
    _isActive = product.isActive;
    _selectedCategoryId = product.categoryId;
    setState(() => _loadingProduct = false);
  }

  Future<void> _loadCategories() async {
    final loaded = await loadProductEditCategories(
      repository: widget.repository,
      selectedCategoryId: _selectedCategoryId,
    );
    if (!mounted) return;
    setState(() {
      _categories = loaded.categories;
      _selectedCategoryId = loaded.selectedId;
      _loadingCategories = false;
    });
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
      showFloatingError(context, context.l10n.adminSelectCategory);
      return;
    }
    final priceText = _priceCtrl.text.trim();
    final price = Money.tryParseMajor(priceText);
    if (price == null) {
      showFloatingError(
        context,
        priceText.startsWith('-')
            ? context.l10n.adminPriceNegative
            : context.l10n.adminInvalidPrice,
      );
      return;
    }
    if (price.minorUnits <= 0) {
      // The DB enforces this too (001: base_price > 0), but failing here
      // gives an inline message instead of a generic save failure.
      showFloatingError(context, context.l10n.adminPriceNegative);
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
      basePrice: price,
      isActive: _isActive,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      success: (_) {
        showConfirmation(
          context,
          widget.productId == null
              ? context.l10n.adminProductCreated
              : context.l10n.adminProductUpdated,
        );
        context.pop(true);
      },
      failure: (error) {
        // Repository messages are fixed, user-facing strings — the raw
        // exception never reaches the UI (leak scrubbed with the Result
        // migration).
        showFloatingError(
          context,
          failureText(context.l10n,
              code: error.code,
              message: error.message,
              fallback: context.l10n.errorTitle),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The form was previously titled "Products" in both modes —
        // indistinguishable from the list page in the back stack.
        title: Text(widget.productId == null
            ? context.l10n.adminNewProduct
            : context.l10n.adminEditProduct),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminProductEditForm(
              nameCtrl: _nameCtrl,
              slugCtrl: _slugCtrl,
              descriptionCtrl: _descriptionCtrl,
              compositionCtrl: _compositionCtrl,
              careCtrl: _careCtrl,
              originCtrl: _originCtrl,
              widthCtrl: _widthCtrl,
              gsmCtrl: _gsmCtrl,
              priceCtrl: _priceCtrl,
              minCutCtrl: _minCutCtrl,
              loadingCategories: _loadingCategories,
              categories: _categories,
              selectedCategoryId: _selectedCategoryId,
              onCategoryChanged: (v) => setState(() => _selectedCategoryId = v),
              sellByLength: _sellByLength,
              onSellByLengthChanged: (v) => setState(() => _sellByLength = v),
              isActive: _isActive,
              onActiveChanged: (v) => setState(() => _isActive = v),
              submitting: _submitting,
              loadingProduct: _loadingProduct,
              isCreate: widget.productId == null,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
