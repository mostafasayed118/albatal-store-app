import 'package:flutter/material.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/entities/admin_catalog.dart';
import '../../domain/repositories/admin_repository.dart';

/// Catalog category management — the hub's "Categories" destination.
///
/// Deliberately read-only: the backend exposes no category write RPC yet
/// (migration 033 added product/variant/image writes only), so pretending
/// otherwise would mean UI that cannot save. This page still earns its
/// place as the hub destination: it shows the real categories with ids
/// (which the product form's category dropdown consumes) and flags
/// inactive ones. When a category write RPC lands, the edit surface
/// belongs here.
class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  List<AdminCategory> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await getIt<AdminRepository>().getAllCategories();
    if (!mounted) return;
    result.when(
      success: (categories) => setState(() {
        _categories = categories;
        _loading = false;
      }),
      failure: (error) => setState(() {
        _loading = false;
        _error = error.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.categories)),
      body: _loading
          ? const FeedbackView(type: FeedbackViewType.loading)
          : _error != null
              ? FeedbackView(
                  type: FeedbackViewType.error,
                  body: _error,
                  onAction: _loadCategories,
                )
              : _categories.isEmpty
                  ? const FeedbackView(
                      type: FeedbackViewType.empty,
                      title: 'No categories yet',
                      body:
                          'Categories are created in the database; the storefront needs at least one.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _categories.length,
                        itemBuilder: (ctx, i) {
                          final c = _categories[i];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.category_outlined,
                                color: c.isActive
                                    ? null
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              title: Text(c.name),
                              subtitle: Text(c.id),
                              trailing: _CategoryChip(isActive: c.isActive),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? scheme.secondary : scheme.outline)
            .withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? scheme.secondary : scheme.outline,
        ),
      ),
    );
  }
}
