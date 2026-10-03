import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/admin_catalog_port.dart';
import '../../domain/repositories/admin_wholesale_prices_port.dart';
import '../cubit/admin_wholesale_prices_cubit.dart';
import '../widgets/wholesale_prices/admin_wholesale_prices_view.dart';

/// Admin wholesale price-list management (078 B2B): list, upsert, delete.
///
/// The router resolves [repository]/[catalogRepository] at the
/// composition root (audit P1); [cubit] can be injected outright by
/// widget tests. Body lives in [AdminWholesalePricesView] (one widget
/// per file).
class AdminWholesalePricesPage extends StatelessWidget {
  const AdminWholesalePricesPage({
    super.key,
    this.cubit,
    this.repository,
    this.catalogRepository,
  }) : assert(
            cubit != null || (repository != null && catalogRepository != null),
            'Provide either cubit or both repositories.');

  final AdminWholesalePricesCubit? cubit;
  final AdminWholesalePricesPort? repository;
  final AdminCatalogPort? catalogRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminWholesalePricesCubit>(
      // The router always injects repositories (or a [cubit] in tests) —
      // the view never service-locates (audit DIP: no getIt in views).
      create: (_) => (cubit ??
          AdminWholesalePricesCubit(
            repository: repository!,
            catalogRepository: catalogRepository!,
          ))
        ..load(),
      child: const AdminWholesalePricesView(),
    );
  }
}
