import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/orders_cubit.dart';
import '../widgets/order_list.dart';

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
                OrderList(
                    orders: state.active,
                    emptyMessage: l.noActiveOrders,
                    isCompleted: false,
                    scheme: scheme),
                OrderList(
                    orders: state.completed,
                    emptyMessage: l.noCompletedOrders,
                    isCompleted: true,
                    scheme: scheme),
                OrderList(
                    orders: state.cancelled,
                    emptyMessage: l.noCancelledOrders,
                    isCompleted: true,
                    scheme: scheme),
              ],
            ),
          ),
        );
      },
    );
  }
}
