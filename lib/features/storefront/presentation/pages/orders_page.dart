import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/orders_cubit.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider(
      create: (_) => OrdersCubit(),
      child: Scaffold(
        appBar: AppBar(title: Text(l.myOrders)),
        body: BlocBuilder<OrdersCubit, int>(
          builder: (context, tab) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(l.active)),
                    ButtonSegment(value: 1, label: Text(l.completed)),
                    ButtonSegment(value: 2, label: Text(l.cancelled)),
                  ],
                  selected: {tab},
                  onSelectionChanged: (x) =>
                      context.read<OrdersCubit>().tab(x.first),
                ),
              ),
              Expanded(
                child: tab == 2
                    ? Center(child: Text(l.noCancelledOrders))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      tab == 0
                                          ? '#ORD-2023-8472'
                                          : '#ORD-2023-8391',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  Text(l.orderItemsSummary),
                                  const SizedBox(height: 12),
                                  if (tab == 0)
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('● ${l.placed}'),
                                          Text('● ${l.shipped}'),
                                          Text('○ ${l.delivered}')
                                        ])
                                  else
                                    Text(l.deliveredOnDate,
                                        style: TextStyle(color: scheme.primary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
