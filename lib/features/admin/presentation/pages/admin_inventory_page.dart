import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/low_stock_variant.dart';
import '../cubit/admin_cubit.dart';
import '../widgets/dialog_controllers.dart';

/// Admin inventory — low stock alerts, stock editing.
class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage>
    with DialogControllers {
  /// Stock edit awaiting repository confirmation — drives the verified
  /// "stock updated" snackbar in the listener below.
  bool _awaitingStockUpdate = false;

  @override
  void dispose() {
    disposeDialogControllers();
    for (final notifier in _dialogErrors) {
      notifier.dispose();
    }
    super.dispose();
  }

  /// Stock-entry error shown under the dialog's field when Update is pressed
  /// with blank or non-numeric input — never silently coerced to 0. A
  /// [ValueNotifier] because the dialog is a separate route that does not
  /// rebuild when the page's setState runs.
  final List<ValueNotifier<String?>> _dialogErrors = [];

  ValueNotifier<String?> _newDialogError() {
    final notifier = ValueNotifier<String?>(null);
    _dialogErrors.add(notifier);
    return notifier;
  }

  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadLowStockProducts();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventory)),
      body: BlocListener<AdminCubit, AdminState>(
        listener: (context, state) {
          // Optimistic acks lie when the write fails; confirm only what
          // the repository actually did.
          if (state.status == AdminStatus.error) {
            if (_awaitingStockUpdate) {
              showFloatingError(
                  context, state.errorMessage ?? context.l10n.errorTitle);
            }
            _awaitingStockUpdate = false;
          } else if (_awaitingStockUpdate &&
              state.status == AdminStatus.ready) {
            showConfirmation(context, context.l10n.stockUpdated);
            _awaitingStockUpdate = false;
          }
        },
        child: BlocBuilder<AdminCubit, AdminState>(
          builder: (context, state) {
            if (state.status == AdminStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == AdminStatus.error) {
              // A failed load must not render as "all stock healthy" —
              // that lies to the person managing inventory.
              return FeedbackView(
                type: FeedbackViewType.error,
                body: state.errorMessage,
                onAction: () =>
                    context.read<AdminCubit>().loadLowStockProducts(),
              );
            }
            final products = state.lowStockProducts;
            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(l10n.allStockLevelsHealthy),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (_, i) => _StockTile(
                product: products[i],
                onEditRequested: () => _showStockDialog(products[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Opens the stock dialog for [product]. Lives on the page State (not
  /// the tile) so the field controller is disposed with the page instead
  /// of while the dialog's exit animation still has the TextField mounted.
  Future<void> _showStockDialog(LowStockVariant product) async {
    // Let the tapped row's frame finish rendering before pushing the dialog;
    // a slow device can otherwise starve the route's opening frame.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final ctrl = newDialogController(product.stock.toString());
    final entryError = _newDialogError();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.updateStock),
        content: ValueListenableBuilder<String?>(
          valueListenable: entryError,
          builder: (context, error, _) => TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              // First keystroke clears a visible rejection.
              if (entryError.value != null) {
                entryError.value = null;
              }
            },
            decoration: InputDecoration(
              labelText: context.l10n.newStockLevel,
              errorText: error,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newStock = int.tryParse(ctrl.text.trim());
              if (newStock == null || newStock < 0) {
                hapticWarning();
                entryError.value = switch (newStock) {
                  null when ctrl.text.trim().isEmpty =>
                    context.l10n.fieldRequired,
                  null => context.l10n.enterValidNumber,
                  _ => context.l10n.stockCannotBeNegative,
                };
                return;
              }
              hapticTap();
              _awaitingStockUpdate = true;
              context.read<AdminCubit>().updateStock(
                    product.variantId,
                    newStock,
                  );
              Navigator.pop(context);
            },
            child: Text(context.l10n.update),
          ),
        ],
      ),
    );
  }
}

final class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.product,
    required this.onEditRequested,
  });

  final LowStockVariant product;

  /// Opens the stock dialog on the page State, which owns the dialog's
  /// field controller lifecycle.
  final VoidCallback onEditRequested;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: product.stock == 0
              ? scheme.error.withValues(alpha: .12)
              : scheme.secondary.withValues(alpha: .12),
          child: Text('${product.stock}',
              style: TextStyle(
                  color: product.stock == 0 ? scheme.error : scheme.secondary,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(product.productName),
        subtitle: Text(product.variantLabel),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEditRequested,
        ),
      ),
    );
  }
}
