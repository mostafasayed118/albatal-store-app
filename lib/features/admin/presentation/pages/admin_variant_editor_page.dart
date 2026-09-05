import 'package:flutter/material.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/entities/admin_variant.dart';
import '../../domain/repositories/admin_repository.dart';

/// Variant editor for a single product — lists variants, add/edit via dialog.
///
/// Consumes the repository's `Result` API via exhaustive switches: no
/// exceptions are caught here and no raw maps are subscripted (audit
/// remediation: T1 catalog methods return `Result<T>` of typed entities).
class AdminVariantEditorPage extends StatefulWidget {
  const AdminVariantEditorPage({super.key, required this.productId});
  final String productId;

  @override
  State<AdminVariantEditorPage> createState() => _AdminVariantEditorPageState();
}

class _AdminVariantEditorPageState extends State<AdminVariantEditorPage> {
  List<AdminVariant> _variants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await getIt<AdminRepository>().getVariants(widget.productId);
    if (!mounted) return;
    result.when(
      success: (variants) => setState(() {
        _variants = variants;
        _loading = false;
      }),
      failure: (error) => setState(() {
        _loading = false;
        _error = error.message;
      }),
    );
  }

  void _showVariantDialog({AdminVariant? existing}) {
    final sizeCtrl = TextEditingController(text: existing?.size ?? '');
    final colorCtrl = TextEditingController(text: existing?.color ?? '');
    final stockCtrl =
        TextEditingController(text: existing?.stock.toString() ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.priceOverride?.toString() ?? '',
    );
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing == null ? 'Add Variant' : 'Edit Variant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sizeCtrl,
                  decoration: const InputDecoration(labelText: 'Size'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(labelText: 'Color'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockCtrl,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Price Override (optional)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : AppButton(
                    label: 'Save',
                    onPressed: () async {
                      if (sizeCtrl.text.trim().isEmpty ||
                          colorCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Size and color are required')),
                        );
                        return;
                      }
                      final stock = int.tryParse(stockCtrl.text.trim());
                      if (stock == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Invalid stock')),
                        );
                        return;
                      }
                      final priceOverride = priceCtrl.text.trim().isEmpty
                          ? null
                          : double.tryParse(priceCtrl.text.trim());
                      if (priceCtrl.text.trim().isNotEmpty &&
                          priceOverride == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Invalid price override')),
                        );
                        return;
                      }
                      setDlgState(() => saving = true);
                      final result = await getIt<AdminRepository>()
                          .adminUpsertVariant(
                        productId: widget.productId,
                        size: sizeCtrl.text.trim(),
                        color: colorCtrl.text.trim(),
                        stock: stock,
                        priceOverride: priceOverride,
                      );
                      if (!ctx.mounted) return;
                      result.when(
                        success: (_) {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Variant saved')),
                          );
                          _loadVariants();
                        },
                        failure: (error) {
                          // Repository messages are fixed, user-facing
                          // strings — safe to render verbatim.
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                          setDlgState(() => saving = false);
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.variants)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        AppButton(label: 'Retry', onPressed: _loadVariants),
                      ],
                    ),
                  ),
                )
              : _variants.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 48),
                            const SizedBox(height: 12),
                            const Text('No variants yet'),
                            const SizedBox(height: 12),
                            AppButton(
                                label: 'Add Variant',
                                onPressed: () => _showVariantDialog()),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadVariants,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _variants.length,
                        itemBuilder: (ctx, i) {
                          final v = _variants[i];
                          final override = v.priceOverride;
                          return Card(
                            child: ListTile(
                              title: Text('${v.size} / ${v.color}'),
                              subtitle: Text(
                                  'Stock: ${v.stock}${override != null ? ' • Override: $override' : ''}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _showVariantDialog(existing: v),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVariantDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
