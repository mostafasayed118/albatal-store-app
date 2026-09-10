import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/admin_catalog.dart';
import '../../domain/repositories/admin_repository.dart';

/// Catalog product management — the hub's "Products" destination.
///
/// Serves two duties by design:
///  1. the manage surface (list every product — including inactive ones —
///     create new, edit, and jump into per-product variant/image editing);
///  2. the product picker the hub's Variants and Images tiles land on
///     (both editors require a product id, which only a list can supply).
///
/// Create is reached via `/admin/products/new` (a route, not a dialog) so
/// a deep link or a future shortcut can open the form directly; editing
/// uses `/admin/products/:id`.
///
/// The repository is constructor-injected (audit P1); the router resolves
/// it at the composition root.
class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  List<AdminProduct> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.repository.getAllProducts();
    if (!mounted) return;
    result.when(
      success: (products) => setState(() {
        _products = products;
        _loading = false;
      }),
      failure: (error) => setState(() {
        _loading = false;
        _error = error.message;
      }),
    );
  }

  /// Product edit is the only flow that returns a "changed" signal
  /// (`context.pop(true)` after a successful save) — refresh so the
  /// list never shows a stale name, price, or active flag.
  Future<void> _editProduct(AdminProduct product) async {
    final changed = await context.push<bool>('/admin/products/${product.id}');
    if (changed == true) await _loadProducts();
  }

  Future<void> _newProduct() async {
    final changed = await context.push<bool>('/admin/products/new');
    if (changed == true) await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.products)),
      body: _loading
          ? const FeedbackView(type: FeedbackViewType.loading)
          : _error != null
              ? FeedbackView(
                  type: FeedbackViewType.error,
                  body: _error,
                  onAction: _loadProducts,
                )
              : _products.isEmpty
                  ? FeedbackView(
                      type: FeedbackViewType.empty,
                      title: 'No products yet',
                      body:
                          'Create the first product so the storefront has something to sell.',
                      actionLabel: 'New Product',
                      onAction: _newProduct,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final p = _products[i];
                          final category =
                              p.categoryName.isNotEmpty ? p.categoryName : '—';
                          // Inactive rows say so in words — the dimmed icon
                          // alone reads as a rendering glitch.
                          final subtitle = p.isActive
                              ? '$category • ${p.slug}'
                              : '$category • ${p.slug} • Inactive';
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                p.isActive
                                    ? Icons.shopping_bag_outlined
                                    : Icons.shopping_bag,
                                color: p.isActive
                                    ? null
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              title: Text(p.name),
                              subtitle: Text(subtitle),
                              // Row opens variant management (the most
                              // frequent per-product task); the trailing
                              // icons cover gallery and the edit form.
                              onTap: () =>
                                  context.push('/admin/variants/${p.id}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Images',
                                    icon: const Icon(Icons.image_outlined),
                                    onPressed: () =>
                                        context.push('/admin/images/${p.id}'),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit product',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editProduct(p),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newProduct,
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
      ),
    );
  }
}
