import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/repositories/recent_searches_store.dart';

final class RecentSearchesState extends Equatable {
  const RecentSearchesState({this.queries = const []});

  final List<String> queries;

  @override
  List<Object?> get props => [queries];
}

/// In-memory mirror of [RecentSearchesStore] for the catalog search UI.
class RecentSearchesCubit extends Cubit<RecentSearchesState> {
  RecentSearchesCubit({required RecentSearchesStore store})
      : _store = store,
        super(const RecentSearchesState());

  final RecentSearchesStore _store;

  void load() => emit(RecentSearchesState(queries: _store.load()));

  void record(String query) {
    _store.record(query);
    emit(RecentSearchesState(queries: _store.load()));
  }

  void clear() {
    _store.clear();
    emit(const RecentSearchesState());
  }
}
