import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/address.dart';
import '../../domain/repositories/address_repository.dart';

enum AddressesStatus { loading, ready, empty, failure }

final class AddressesState extends Equatable {
  const AddressesState(
      {this.status = AddressesStatus.loading,
      this.addresses = const [],
      this.errorMessage});
  final AddressesStatus status;
  final List<Address> addresses;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, addresses, errorMessage];
}

final class AddressesCubit extends Cubit<AddressesState> {
  AddressesCubit(this._repository) : super(const AddressesState());
  final AddressRepository _repository;

  /// Reload persisted addresses.
  ///
  /// By default this is a startup fill: if the user already acted
  /// (non-empty book) a late-completing read must NOT clobber live
  /// state (live-found 2026-09-03: a stale address replaced the fresh
  /// selection mid-checkout and the server was sent the wrong
  /// address snapshot). Pass [force] for an explicit manual refresh.
  Future<void> load({bool force = false}) async {
    // Capture live data BEFORE the reset emit below: on guard-skip we
    // must restore it, otherwise the reset would wipe the display.
    final live = state.addresses;
    emit(const AddressesState());
    final r = await _repository.read();
    r.when(
        success: (a) {
          if (force || live.isEmpty) {
            emit(AddressesState(
                status:
                    a.isEmpty ? AddressesStatus.empty : AddressesStatus.ready,
                addresses: a));
          } else {
            emit(
                AddressesState(status: AddressesStatus.ready, addresses: live));
          }
        },
        failure: (e) => emit(AddressesState(
            status: AddressesStatus.failure, errorMessage: e.message)));
  }

  Future<void> upsert(Address a) async =>
      _persist(_normalise([...state.addresses.where((x) => x.id != a.id), a]));
  Future<void> remove(String id) async =>
      _persist(_normalise(state.addresses.where((a) => a.id != id).toList()));
  Future<void> setDefault(String id) async => _persist(
      state.addresses.map((a) => a.copyWith(isDefault: a.id == id)).toList());
  List<Address> _normalise(List<Address> a) =>
      a.isEmpty || a.any((x) => x.isDefault)
          ? a
          : [a.first.copyWith(isDefault: true), ...a.skip(1)];
  Future<void> _persist(List<Address> a) async {
    final r = await _repository.save(a);
    r.when(
        success: (_) => emit(AddressesState(
            status: a.isEmpty ? AddressesStatus.empty : AddressesStatus.ready,
            addresses: a)),
        failure: (e) => emit(AddressesState(
            status: AddressesStatus.failure,
            addresses: state.addresses,
            errorMessage: e.message)));
  }
}
