import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/orders_cubit.dart';
import 'status_progress.dart';

/// Single order card with Stitch surface + outlineVariant border (16dp) + primaryContainer status pill.
class OrderCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    final o = order;
    final firstProductName = o.items.isEmpty ? '' : o.items.first.product.name;
    final isActive = !isCompleted && o.status != OrderStatus.cancelled;

    return Card(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
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
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$firstProductName · ${l.itemsCount(o.itemCount)}'),
            const SizedBox(height: 12),
            if (isActive)
              StatusProgress(status: o.status, scheme: scheme)
            else
              Text('${l.delivered} · ${_fmtDate(o.placedAt)}',
                  style: TextStyle(color: scheme.primary)),
            if (isActive) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => context.read<OrdersCubit>().advance(o.id),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(l.advanceOrder),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(OrderStatus s, AppLocalizations l) => switch (s) {
        OrderStatus.pending => l.placed,
        OrderStatus.placed => l.placed,
        OrderStatus.paid => l.placed,
        OrderStatus.processing => l.placed,
        OrderStatus.shipped => l.shipped,
        OrderStatus.delivered => l.delivered,
        OrderStatus.cancelled => l.cancelled,
        OrderStatus.refunded => l.cancelled,
      };
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
