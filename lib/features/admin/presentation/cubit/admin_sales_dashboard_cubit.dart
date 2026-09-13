import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/admin_sales.dart';
import '../../domain/entities/low_stock_variant.dart';
import '../../domain/repositories/admin_repository.dart';

enum AdminSalesDashboardStatus { loading, loaded, error }

final class AdminSalesDashboardState extends Equatable {
  const AdminSalesDashboardState({
    this.status = AdminSalesDashboardStatus.loading,
    this.overview,
    this.lowStock = const [],
    this.errorMessage,
  });

  final AdminSalesDashboardStatus status;

  /// Aggregated sales read model — non-null once loaded.
  final AdminSalesOverview? overview;

  /// Low-stock variants (threshold <= 5) for the secondary panel.
  final List<LowStockVariant> lowStock;

  final String? errorMessage;

  @override
  List<Object?> get props => [status, overview, lowStock, errorMessage];
}

/// Loads the read-only sales overview (#12) and the low-stock list for
/// the admin sales dashboard. Failures are values ([Result]) handled at
/// this boundary; every await is followed by an [isClosed] guard so a
/// disposed cubit never emits after close.
class AdminSalesDashboardCubit extends Cubit<AdminSalesDashboardState> {
  AdminSalesDashboardCubit({required AdminRepository repository})
      : _repository = repository,
        super(const AdminSalesDashboardState());

  final AdminRepository _repository;

  Future<void> load() async {
    emit(const AdminSalesDashboardState(
      status: AdminSalesDashboardStatus.loading,
    ));
    final results = await Future.wait([
      _repository.getSalesOverview(),
      _repository.getLowStockProducts(),
    ]);
    if (isClosed) return;
    final overviewResult = results[0] as Result<AdminSalesOverview>;
    final lowStockResult = results[1] as Result<List<LowStockVariant>>;
    switch (overviewResult) {
      case Success(:final value):
        // Low stock is a secondary panel: if only it fails, the page
        // still renders with an empty list instead of a full-screen
        // error that would also hide the revenue chart.
        final lowStock = switch (lowStockResult) {
          Success(:final value) => value,
          Failure() => const <LowStockVariant>[],
        };
        emit(AdminSalesDashboardState(
          status: AdminSalesDashboardStatus.loaded,
          overview: value,
          lowStock: lowStock,
        ));
      case Failure(:final error):
        emit(AdminSalesDashboardState(
          status: AdminSalesDashboardStatus.error,
          errorMessage: error.message,
        ));
    }
  }
}
