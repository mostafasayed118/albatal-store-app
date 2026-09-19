import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/profile.dart';
import '../../../../shared/components/app_card.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/entities/admin_customer.dart';
import '../../domain/repositories/admin_repository.dart';
import '../cubit/admin_customers_cubit.dart';
import '../widgets/membership_tier_dialog.dart';

/// Admin customers list (feature-batch §14): profile directory with
/// membership tier + contact columns, and the tier control the spec asked
/// for — a tier is changeable from the directory itself instead of only
/// from an order belonging to that customer.
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

  /// Localised tier name for a raw column value. Unknown values fall back
  /// to the standard label, matching the order-detail customer card.
  String _tierLabel(String raw) =>
      membershipTierFromServerValue(raw) == MembershipTier.premium
          ? context.l10n.premiumMember
          : context.l10n.standardMember;

  /// Opens the shared tier picker for [customer] and persists a real change.
  ///
  /// [cubit] is passed in rather than read here on purpose. This page *creates*
  /// its [BlocProvider] inside [build], so the provider is a descendant of
  /// this State's context and `context.read` from here would throw. Every
  /// post-await use below is this State's own context, guarded by [mounted],
  /// so the async gap never touches a row context that may be gone.
  ///
  /// Nothing is acknowledged on the strength of the tap: the snackbar is
  /// chosen from what the cubit *actually* holds after the write — the row's
  /// new tier, or the failure it reported instead.
  Future<void> _changeTier(
    AdminCustomersCubit cubit,
    AdminCustomer customer,
  ) async {
    final selection = await showMembershipTierDialog(
      context,
      currentTier: customer.tier,
    );
    // Null means cancelled or unchanged — never write, never ack.
    if (selection == null || !mounted) return;
    hapticWarning();
    await cubit.setMembershipTier(customer.id, selection);
    if (!mounted) return;
    final error = cubit.state.tierError;
    if (error != null) {
      showFloatingError(context, error);
      cubit.clearTierError();
      return;
    }
    if (_tierOf(cubit, customer.id) == selection) {
      showConfirmation(context, context.l10n.membershipTierUpdated);
    }
  }

  /// The directory's current tier for [id], or null when no such row is
  /// loaded — which is what stops an unacknowledged write from claiming
  /// success.
  String? _tierOf(AdminCustomersCubit cubit, String id) {
    for (final c in cubit.state.customers) {
      if (c.id == id) return c.tier;
    }
    return null;
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
                    // Searches the server, so the term reaches customers on
                    // pages this screen has not loaded yet. `adminSearch` is
                    // the shared generic label (the catalog hub uses it too),
                    // so the directory names its own columns here — a phone
                    // search nobody knows about is barely better than none.
                    onChanged: (q) =>
                        context.read<AdminCustomersCubit>().search(q),
                    decoration: InputDecoration(
                      hintText: l.adminSearchCustomersHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                // The count is the antidote to the old silent cap: it says
                // how many customers exist, not just how many are on screen.
                if (state.customers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l.customersShownOf(state.customers.length, state.total),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                Expanded(
                  child: state.customers.isEmpty
                      ? Center(child: Text(l.noResultsFound))
                      : ListView.separated(
                          padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 16),
                          itemCount:
                              state.customers.length + (state.hasMore ? 1 : 0),
                          separatorBuilder: (context, i) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            // Last slot is the paging footer, present only
                            // while the server still holds unloaded rows.
                            if (i == state.customers.length) {
                              return Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                    vertical: 16),
                                child: state.isLoadingMore
                                    ? const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : Center(
                                        child: TextButton(
                                          onPressed: () => context
                                              .read<AdminCustomersCubit>()
                                              .loadMore(),
                                          child: Text(l.loadMore),
                                        ),
                                      ),
                              );
                            }
                            final c = state.customers[i];
                            // Contact column: email when the schema supplies
                            // one, otherwise the phone that `profiles`
                            // actually has. Hidden when empty so the row
                            // never renders a blank subtitle.
                            final contact = c.contact;
                            return AppCard(
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
                                // The tier sits on the contact line rather
                                // than in the trailing slot: trailing is the
                                // control now, where a tier label would read
                                // as the button's caption.
                                subtitle: Text([
                                  if (contact.isNotEmpty) contact,
                                  _tierLabel(c.tier),
                                ].join(' • ')),
                                trailing: TextButton(
                                  // Resolved from the row's context — the only
                                  // context under the provider this page
                                  // creates — then handed straight to the
                                  // async writer.
                                  onPressed: () => _changeTier(
                                      context.read<AdminCustomersCubit>(), c),
                                  child: Text(l.change),
                                ),
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
