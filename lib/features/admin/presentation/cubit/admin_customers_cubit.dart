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
  });

  final AdminCustomersStatus status;

  /// Full directory; [visible] is the search-filtered view.
  final List<AdminCustomer> customers;
  final List<AdminCustomer> visible;
  final String? errorMessage;

  AdminCustomersState copyWith({
    AdminCustomersStatus? status,
    List<AdminCustomer>? customers,
    List<AdminCustomer>? visible,
    String? errorMessage,
  }) =>
      AdminCustomersState(
        status: status ?? this.status,
        customers: customers ?? this.customers,
        visible: visible ?? this.visible,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, customers, visible, errorMessage];
}

/// Customer directory for the admin hub (feature-batch §14). The page
/// renders this cubit instead of calling the repository from its State
/// (audit 2026-09-13).
class AdminCustomersCubit extends Cubit<AdminCustomersState> {
  AdminCustomersCubit({required AdminRepository repository})
      : _repository = repository,
        super(const AdminCustomersState());

  final AdminRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminCustomersStatus.loading));
    final result = await _repository.fetchCustomers();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(
          status: AdminCustomersStatus.ready,
          customers: value,
          visible: value,
        ));
      case Failure(:final error):
        emit(state.copyWith(
            status: AdminCustomersStatus.error, errorMessage: error.message));
    }
  }

  void filter(String query) {
    final q = query.trim().toLowerCase();
    emit(state.copyWith(
      visible: q.isEmpty
          ? state.customers
          : state.customers
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.email.toLowerCase().contains(q))
              .toList(),
    ));
  }
}
