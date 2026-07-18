import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/orders_cubit.dart';
import '../widgets/empty_state_view.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        if (state.status == OrdersStatus.loading) {
          return Scaffold(
            appBar: AppBar(title: Text(l.myOrders)),
            body: const FeedbackView(type: FeedbackViewType.loading),
          );
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l.myOrders),
              bottom: TabBar(
                tabs: [
                  Tab(text: l.active),
                  Tab(text: l.completed),
                  Tab(text: l.cancelled),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OrderList(
                  orders: state.active,
                  emptyMessage: l.noActiveOrders,
                  isCompleted: false,
                  scheme: scheme,
                ),
                _OrderList(
                  orders: state.completed,
                  emptyMessage: l.noCompletedOrders,
                  isCompleted: true,
                  scheme: scheme,
                ),
                _OrderList(
                  orders: state.cancelled,
                  emptyMessage: l.noCancelledOrders,
                  isCompleted: true,
                  scheme: scheme,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.emptyMessage,
    required this.isCompleted,
    required this.scheme,
  });

  final List orders;
  final String emptyMessage;
  final bool isCompleted;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (orders.isEmpty) {
      return EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: emptyMessage,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final o = orders[i];
        final firstProductName =
            o.items.isEmpty ? '' : o.items.first.product.name;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('#${o.id}',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Text(_statusLabel(o.status, l),
                        style: TextStyle(
                            color: scheme.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$firstProductName · ${l.itemsCount(o.itemCount)}'),
                const SizedBox(height: 12),
                if (!isCompleted && o.status != OrderStatus.cancelled)
                  _StatusProgress(status: o.status, scheme: scheme)
                else
                  Text('${l.delivered} · ${o.placedAt.formatted}',
                      style: TextStyle(color: scheme.primary)),
                if (!isCompleted && o.status != OrderStatus.cancelled) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () =>
                          context.read<OrdersCubit>().advance(o.id),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(l.advanceOrder),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(OrderStatus s, AppLocalizations l) => switch (s) {
        OrderStatus.placed => l.placed,
        OrderStatus.shipped => l.shipped,
        OrderStatus.delivered => l.delivered,
        OrderStatus.cancelled => l.cancelled,
      };
}

class _StatusProgress extends StatelessWidget {
  const _StatusProgress({required this.status, required this.scheme});
  final OrderStatus status;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [
      (OrderStatus.placed, l.placed),
      (OrderStatus.shipped, l.shipped),
      (OrderStatus.delivered, l.delivered),
    ];
    final reached = steps.indexWhere((s) => s.$1 == status);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < steps.length; i++)
          Text(
            '${i <= reached ? '●' : '○'} ${steps[i].$2}',
            style: TextStyle(
              color: i <= reached
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: .5),
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
