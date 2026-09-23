import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/admin_coupons_port.dart';
import '../cubit/admin_coupons_cubit.dart';
import '../widgets/coupons/admin_coupons_view.dart';

export '../widgets/coupons/admin_coupons_view.dart' show safeMinorToEgpLabel;

/// Admin coupon management (feature-batch §8): list, create, activate.
///
/// The router resolves [repository] at the composition root (audit P1);
/// [cubit] can be injected outright by widget tests. Body lives in
/// [AdminCouponsView] (one widget per file).
class AdminCouponsPage extends StatelessWidget {
  const AdminCouponsPage({super.key, this.cubit, this.repository})
      : assert(cubit != null || repository != null,
            'Provide either cubit or repository.');

  final AdminCouponsCubit? cubit;
  final AdminCouponsPort? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminCouponsCubit>(
      // The router always injects [repository] (or a [cubit] in tests) —
      // the view never service-locates (audit DIP: no getIt in views).
      create: (_) =>
          (cubit ?? AdminCouponsCubit(repository: repository!))..load(),
      child: const AdminCouponsView(),
    );
  }
}
