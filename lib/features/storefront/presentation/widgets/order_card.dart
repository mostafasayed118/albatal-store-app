import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/components/app_card.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/orders_cubit.dart';
import '../cubit/reorder_cubit.dart';
import 'order_status_timeline.dart';
import 'status_progress.dart';

/// Single order card with Stitch surface + outlineVariant border (16dp) + primaryContainer status pill.
///
/// Tapping the card expands a detail area holding the order-status
/// timeline (#4). Collapsed content is unchanged, so the orders list
/// behavior is preserved.
class OrderCard extends StatefulWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.isCompleted,
    required this.scheme,
  });
  final Order order;
  final bool isCompleted;
  final ColorScheme scheme;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = widget.scheme;
    final o = widget.order;
    final firstProductName = o.items.isEmpty ? '' : o.items.first.product.name;
    final isActive = !widget.isCompleted && o.status != OrderStatus.cancelled;

    return AppCard(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('#${o.id}',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  // Stitch pill status chip: primaryContainer fill when applicable.
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(o.status, l),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurface.withValues(alpha: .6),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('$firstProductName · ${l.itemsCount(o.itemCount)}'),
              const SizedBox(height: 12),
              if (isActive)
                StatusProgress(status: o.status, scheme: scheme)
              else
                // Closed orders show their own outcome + date — never a
                // hardcoded 'Delivered' (live-found 2026-09-04: just-paid
                // orders read 'Delivered · today').
                Text(
                    '${_closedLabel(o.status, l)} · ${_fmtDate(o.placedAt, l.localeName)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.primary)),
              if (_expanded) ...[
                const Divider(height: 24),
                Text(l.orderTimelineTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                // Per-step timestamps degrade gracefully: the orders API
                // exposes only placedAt today.
                OrderStatusTimeline(
                  status: o.status,
                  scheme: scheme,
                  placedAt: o.placedAt,
                ),
              ],
              const SizedBox(height: 4),
              // §6: one-tap reorder — every line is re-validated against
              // the live catalog and stock inside ReorderCubit.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: o.items.isEmpty
                      ? null
                      : () => context.read<ReorderCubit>().reorder(o),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l.reorder),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(OrderStatus s, AppLocalizations l) => switch (s) {
        OrderStatus.pending => l.placed,
        OrderStatus.placed => l.placed,
        OrderStatus.paid => l.paid,
        OrderStatus.processing => l.processing,
        OrderStatus.shipped => l.shipped,
        OrderStatus.delivered => l.delivered,
        OrderStatus.cancelled => l.cancelled,
        OrderStatus.refunded => l.cancelled,
        OrderStatus.expired => l.cancelled,
      };

  String _closedLabel(OrderStatus s, AppLocalizations l) => switch (s) {
        OrderStatus.delivered => l.delivered,
        OrderStatus.paid => l.paid,
        _ => l.cancelled,
      };
}

/// Locale-aware closed-order date — month names follow the UI locale via
/// intl (the old hardcoded English list leaked "Jan…Dec" into AR history).
String _fmtDate(DateTime d, String locale) =>
    DateFormat('d MMM y', locale).format(d);
