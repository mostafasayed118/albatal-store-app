import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/components/app_card.dart';
import '../../../../../shared/components/feedback_view.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../../domain/entities/admin_wholesale_price_entry.dart';
import '../../cubit/admin_wholesale_prices_cubit.dart';
import '../admin_error_feedback.dart';
import '../coupons/admin_coupons_view.dart' show safeMinorToEgpLabel;

/// Admin wholesale price-list screen (078 B2B): every negotiated price
/// with add/edit (sheet) and delete (confirm dialog).
final class AdminWholesalePricesView extends StatelessWidget {
  const AdminWholesalePricesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminWholesalePrices)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPriceSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l.adminAddWholesalePrice),
      ),
      body: BlocBuilder<AdminWholesalePricesCubit, AdminWholesalePricesState>(
        builder: (context, state) {
          if (state.status == AdminWholesalePricesStatus.loading) {
            return const FeedbackView(type: FeedbackViewType.loading);
          }
          if (state.status == AdminWholesalePricesStatus.error) {
            return AdminErrorFeedback(
              errorCode: state.errorCode,
              errorMessage: state.errorMessage,
              onRetry: () => context.read<AdminWholesalePricesCubit>().load(),
            );
          }
          if (state.entries.isEmpty) {
            // Bare empty state: the add-price FAB carries the action.
            return FeedbackView(
              type: FeedbackViewType.empty,
              icon: Icons.sell_outlined,
              body: l.adminAddWholesalePrice,
            );
          }
          return ListView.separated(
            padding: const EdgeInsetsDirectional.all(16),
            itemCount: state.entries.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = state.entries[i];
              return AppCard(
                child: ListTile(
                  title: Text(entry.productName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(safeMinorToEgpLabel(entry.priceMinor)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l.adminEditWholesalePrice,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showPriceSheet(context, entry),
                      ),
                      IconButton(
                        tooltip: l.adminDeleteWholesalePrice,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmDelete(context, entry.productId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Add ([entry] == null) or edit ([entry] != null) one negotiated
  /// price. The price field takes EGP major units and submits minor
  /// units — same contract as the coupon discount sheet. Editing pins
  /// the product (read-only name) so the upsert always targets the
  /// existing row.
  Future<void> _showPriceSheet(BuildContext context,
      [AdminWholesalePriceEntry? entry]) async {
    final priceController = TextEditingController(
        text: entry == null ? '' : (entry.priceMinor ~/ 100).toString());
    String? selectedProductId;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              top: 16,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry != null)
                  TextFormField(
                    enabled: false,
                    initialValue: entry.productName,
                    decoration: InputDecoration(
                        labelText:
                            sheetContext.l10n.adminWholesalePriceProduct),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedProductId,
                    items: [
                      for (final product in sheetContext
                          .read<AdminWholesalePricesCubit>()
                          .state
                          .products)
                        DropdownMenuItem(
                            value: product.id, child: Text(product.name)),
                    ],
                    onChanged: (productId) =>
                        setSheetState(() => selectedProductId = productId),
                    decoration: InputDecoration(
                        labelText:
                            sheetContext.l10n.adminWholesalePriceProduct),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: sheetContext.l10n.adminWholesalePriceEgp),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final productId = entry?.productId ?? selectedProductId;
                    final egp = int.tryParse(priceController.text.trim());
                    if (productId == null || egp == null || egp <= 0) return;
                    sheetContext
                        .read<AdminWholesalePricesCubit>()
                        .upsertPrice(productId: productId, priceMinor: egp * 100);
                    Navigator.of(sheetContext).pop();
                  },
                  child: Text(entry == null
                      ? sheetContext.l10n.adminAddWholesalePrice
                      : sheetContext.l10n.adminEditWholesalePrice),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      // Disposed after the sheet is fully popped (covers confirm,
      // cancel, and barrier dismissal) — same contract as the admin
      // dialog controllers (PR #34 sweep).
      priceController.dispose();
    }
  }

  Future<void> _confirmDelete(BuildContext context, String productId) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.adminDeleteWholesalePrice),
        content: Text(l.adminWholesalePriceDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      unawaited(
          context.read<AdminWholesalePricesCubit>().deletePrice(productId));
    }
  }
}
