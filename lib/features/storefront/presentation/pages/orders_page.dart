import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/orders_cubit.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OrdersCubit(),
        child: Scaffold(
          appBar: AppBar(title: const Text('My Orders')),
          body: BlocBuilder<OrdersCubit, int>(
            builder: (context, tab) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Active')),
                      ButtonSegment(value: 1, label: Text('Completed')),
                      ButtonSegment(value: 2, label: Text('Cancelled')),
                    ],
                    selected: {tab},
                    onSelectionChanged: (x) =>
                        context.read<OrdersCubit>().tab(x.first),
                  ),
                ),
                Expanded(
                  child: tab == 2
                      ? const Center(child: Text('No cancelled orders'))
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
                                    const Text('Royal Emerald Silk · 2 items'),
                                    const SizedBox(height: 12),
                                    if (tab == 0)
                                      const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('● Placed'),
                                            Text('● Shipped'),
                                            Text('○ Delivered')
                                          ])
                                    else
                                      const Text('Delivered · 12 July 2026',
                                          style: TextStyle(
                                              color: Color(0xFF064E3B))),
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
