import 'package:flutter/material.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/entities/admin_variant.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/dialog_controllers.dart';

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

class _AdminVariantEditorPageState extends State<AdminVariantEditorPage>
    with DialogControllers {
  List<AdminVariant> _variants = [];
  bool _loading = true;
  String? _error;

  @override
  void dispose() {
    disposeDialogControllers();
    super.dispose();
  }

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

  Future<void> _showVariantDialog({AdminVariant? existing}) async {
    // Let the tapped row's frame finish rendering before pushing the dialog;
    // a slow device can otherwise starve the route's opening frame.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final sizeCtrl = newDialogController(existing?.size ?? '');
    final colorCtrl = newDialogController(existing?.color ?? '');
    final stockCtrl = newDialogController(existing?.stock.toString() ?? '');
    final priceCtrl = newDialogController(
      existing?.priceOverride?.toString() ?? '',
    );
    bool saving = false;

    await showDialog<void>(
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
                        showFloatingError(ctx, 'Size and color are required');
                        return;
                      }
                      final stock = int.tryParse(stockCtrl.text.trim());
                      if (stock == null) {
                        showFloatingError(ctx, 'Invalid stock');
                        return;
                      }
                      if (stock < 0) {
                        // The DB enforces this too (001: stock >= 0), but
                        // failing here gives an inline message instead of a
                        // generic save failure.
                        showFloatingError(ctx, 'Stock cannot be negative');
                        return;
                      }
                      final priceOverride = priceCtrl.text.trim().isEmpty
                          ? null
                          : double.tryParse(priceCtrl.text.trim());
                      if (priceCtrl.text.trim().isNotEmpty &&
                          priceOverride == null) {
                        showFloatingError(ctx, 'Invalid price override');
                        return;
                      }
                      if (priceOverride != null && priceOverride <= 0) {
                        // No DB guard existed for price_override until
                        // migration 044 — this is the first line of defense;
                        // the CHECK is the last.
                        showFloatingError(
                            ctx, 'Price override cannot be negative');
                        return;
                      }
                      setDlgState(() => saving = true);
                      final result =
                          await getIt<AdminRepository>().adminUpsertVariant(
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
                          showConfirmation(context, 'Variant saved');
                          _loadVariants();
                        },
                        failure: (error) {
                          // Repository messages are fixed, user-facing
                          // strings — safe to render verbatim.
                          showFloatingError(ctx, error.message);
                          setDlgState(() => saving = false);
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
    // Controllers stay alive on the page State until the page itself is
    // disposed — the dialog's exit animation may still have them mounted.
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
