import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';
import '../cubit/admin_customers_cubit.dart';

/// Admin customers list (feature-batch §14): profile directory with
/// membership tier + contact columns. Read-only in this batch — tier
/// control lives on the order-detail surface it already belongs to.
/// Rendered via [AdminCustomersCubit] (audit 2026-09-13); the State
/// owns only the search field's text controller.
class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({super.key, this.cubit, this.repository});

  final AdminCustomersCubit? cubit;
  final AdminRepository? repository;

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  // Page-owned so it disposes with the route; the search text flows
  // into the cubit via [AdminCustomersCubit.filter].
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider<AdminCustomersCubit>(
      create: (_) => (widget.cubit ??
          AdminCustomersCubit(
              repository: widget.repository ?? getIt<AdminRepository>()))
        ..load(),
      child: BlocBuilder<AdminCustomersCubit, AdminCustomersState>(
        builder: (context, state) {
          if (state.status == AdminCustomersStatus.loading) {
            return Scaffold(
              appBar: AppBar(title: Text(l.adminCustomers)),
              body: const FeedbackView(type: FeedbackViewType.loading),
            );
          }
          if (state.status == AdminCustomersStatus.error) {
            return Scaffold(
              appBar: AppBar(title: Text(l.adminCustomers)),
              body: FeedbackView(
                type: FeedbackViewType.error,
                body: state.errorMessage,
                onAction: () => context.read<AdminCustomersCubit>().load(),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(title: Text(l.adminCustomers)),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (q) =>
                        context.read<AdminCustomersCubit>().filter(q),
                    decoration: InputDecoration(
                      hintText: l.adminSearch,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: state.visible.isEmpty
                      ? Center(child: Text(l.adminSearch))
                      : ListView.separated(
                          padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 16),
                          itemCount: state.visible.length,
                          separatorBuilder: (context, i) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final c = state.visible[i];
                            // Contact column: email when the schema supplies
                            // one, otherwise the phone that `profiles`
                            // actually has. Hidden when empty so the row
                            // never renders a blank subtitle.
                            final contact = c.contact;
                            return Card(
                              color: scheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppTheme.cardRadius,
                                side: BorderSide(
                                    color: scheme.outlineVariant, width: 1),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: scheme.primaryContainer,
                                  child: Text(
                                    c.name.isEmpty
                                        ? '?'
                                        : c.name[0].toUpperCase(),
                                    style: TextStyle(
                                        color: scheme.onPrimaryContainer),
                                  ),
                                ),
                                title: Text(c.name.isEmpty
                                    ? (contact.isEmpty ? '?' : contact)
                                    : c.name),
                                subtitle:
                                    contact.isEmpty ? null : Text(contact),
                                trailing: Text(c.tier),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
