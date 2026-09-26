import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/share_service.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/orders_csv_exporter.dart';
import '../cubit/admin_cubit.dart';
import '../widgets/admin_error_feedback.dart';
import '../widgets/dashboard/admin_order_tile.dart';

/// Admin order queue — filter by status, export the view as CSV.
class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key, required this.shareService});

  /// Share sink for the CSV export (feature-batch §14). Required,
  /// resolved at the composition root — the view never service-locates
  /// (audit DIP: no getIt in views); widget tests pass a recording fake.
  final ShareService shareService;

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadOrders();
  }

  /// Exports exactly the queue the admin is looking at — the filtered
  /// rows, not every loaded order — so the CSV always matches what the
  /// screen shows.
  Future<void> _exportCsv() async {
    final orders = context.read<AdminCubit>().state.filteredOrders;
    if (orders.isEmpty) return;
    await widget.shareService.shareFile(
      fileName: ordersCsvFileName(DateTime.now()),
      content: buildOrdersCsv(orders),
      mimeType: 'text/csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderQueue),
        actions: [
          // Exporting is only meaningful with rows to export, so the
          // action disables itself on an empty queue rather than sharing
          // a header-only file.
          BlocBuilder<AdminCubit, AdminState>(
            buildWhen: (prev, next) =>
                prev.filteredOrders.isEmpty != next.filteredOrders.isEmpty,
            builder: (context, state) => IconButton(
              tooltip: l10n.exportOrdersCsv,
              onPressed: state.filteredOrders.isEmpty
                  ? null
                  : () => unawaited(_exportCsv()),
              icon: const Icon(Icons.share_outlined),
            ),
          ),
          PopupMenuButton<AdminOrderStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              context.read<AdminCubit>().loadOrders(status: status);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(l10n.allOrders)),
              PopupMenuItem(
                  value: AdminOrderStatus.placed, child: Text(l10n.placed)),
              PopupMenuItem(
                  value: AdminOrderStatus.processing,
                  child: Text(l10n.processing)),
              PopupMenuItem(
                  value: AdminOrderStatus.shipped, child: Text(l10n.shipped)),
              PopupMenuItem(
                  value: AdminOrderStatus.delivered,
                  child: Text(l10n.delivered)),
              PopupMenuItem(
                  value: AdminOrderStatus.cancelled,
                  child: Text(l10n.cancelled)),
            ],
          ),
        ],
      ),
      body: BlocBuilder<AdminCubit, AdminState>(
        // Queue views only: low-stock loads, order-detail loads and
        // tier writes emit without touching `orders`/`statusFilter`
        // (audit 2026-09-21 perf LOW).
        buildWhen: (a, b) =>
            a.status != b.status ||
            a.statusFilter != b.statusFilter ||
            !identical(a.orders, b.orders),
        builder: (context, state) {
          if (state.status == AdminStatus.loading) {
            return const FeedbackView(type: FeedbackViewType.loading);
          }
          if (state.status == AdminStatus.error) {
            // A failed load must not read as an empty queue.
            return AdminErrorFeedback(
              errorCode: state.errorCode,
              errorMessage: state.errorMessage,
              onRetry: () => context.read<AdminCubit>().loadOrders(),
            );
          }
          final orders = state.filteredOrders;
          if (orders.isEmpty) {
            return FeedbackView(
              type: FeedbackViewType.empty,
              icon: Icons.receipt_long_outlined,
              title: l10n.noOrdersFound,
              body: l10n.noOrdersFoundBody,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (_, i) => AdminOrderTile(order: orders[i]),
          );
        },
      ),
    );
  }
}
