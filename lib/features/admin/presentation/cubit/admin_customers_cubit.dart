import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/admin_customer.dart';
import '../../domain/repositories/admin_repository.dart';

enum AdminCustomersStatus { initial, loading, ready, error }

final class AdminCustomersState extends Equatable {
  const AdminCustomersState({
    this.status = AdminCustomersStatus.initial,
    this.customers = const [],
    this.visible = const [],
    this.errorMessage,
    this.tierError,
  });

  final AdminCustomersStatus status;

  /// Full directory; [visible] is the search-filtered view.
  final List<AdminCustomer> customers;
  final List<AdminCustomer> visible;
  final String? errorMessage;

  /// Failure from a tier *write*, kept off [status] deliberately: this page
  /// renders a whole-screen error view for [AdminCustomersStatus.error], so
  /// reusing it would erase the loaded directory whenever a write bounced.
  /// The page surfaces this as a floating message and clears it.
  final String? tierError;

  AdminCustomersState copyWith({
    AdminCustomersStatus? status,
    List<AdminCustomer>? customers,
    List<AdminCustomer>? visible,
    String? errorMessage,
    String? tierError,
    bool clearTierError = false,
  }) =>
      AdminCustomersState(
        status: status ?? this.status,
        customers: customers ?? this.customers,
        visible: visible ?? this.visible,
        errorMessage: errorMessage,
        // Same sentinel convention as AdminState.copyWith(clearSelectedOrder).
        tierError: clearTierError ? null : (tierError ?? this.tierError),
      );

  @override
  List<Object?> get props =>
      [status, customers, visible, errorMessage, tierError];
}

/// Customer directory for the admin hub (feature-batch §14). The page
/// renders this cubit instead of calling the repository from its State
/// (audit 2026-09-13).
class AdminCustomersCubit extends Cubit<AdminCustomersState> {
  AdminCustomersCubit({required AdminRepository repository})
      : _repository = repository,
        super(const AdminCustomersState());

  final AdminRepository _repository;

  /// The active search text, lower-cased. Held so a tier write can re-derive
  /// [AdminCustomersState.visible] instead of leaving the filtered view
  /// showing the pre-write tier.
  String _query = '';

  Future<void> load() async {
    emit(state.copyWith(status: AdminCustomersStatus.loading));
    final result = await _repository.fetchCustomers();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(
          status: AdminCustomersStatus.ready,
          customers: value,
          visible: _filtered(value),
        ));
      case Failure(:final error):
        emit(state.copyWith(
            status: AdminCustomersStatus.error, errorMessage: error.message));
    }
  }

  void filter(String query) {
    _query = query.trim().toLowerCase();
    emit(state.copyWith(visible: _filtered(state.customers)));
  }

  /// Set a customer's membership tier via the admin-gated RPC (migration
  /// 046). On success the directory row reflects the new tier immediately —
  /// the repository confirmed the write before this emits, so the page can
  /// verify its ack against state like every other admin transition.
  ///
  /// A failure never touches [AdminCustomersState.status] (see
  /// [AdminCustomersState.tierError]); it must not erase the directory.
  Future<void> setMembershipTier(String profileId, String tier) async {
    final result = await _repository.setMembershipTier(profileId, tier);
    if (isClosed) return;
    switch (result) {
      case Success():
        final updated = state.customers
            .map((c) => c.id == profileId ? c.copyWith(tier: tier) : c)
            .toList();
        emit(state.copyWith(customers: updated, visible: _filtered(updated)));
      case Failure(:final error):
        emit(state.copyWith(tierError: error.message));
    }
  }

  /// Dismiss the tier-write error once the page has surfaced it.
  void clearTierError() => emit(state.copyWith(clearTierError: true));

  List<AdminCustomer> _filtered(List<AdminCustomer> all) => _query.isEmpty
      ? all
      : all
          .where((c) =>
              c.name.toLowerCase().contains(_query) ||
              c.email.toLowerCase().contains(_query))
          .toList();
}
