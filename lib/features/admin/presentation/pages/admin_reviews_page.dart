import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/admin_reviews_port.dart';
import '../cubit/admin_reviews_cubit.dart';
import '../widgets/reviews/admin_reviews_view.dart';

/// Admin review moderation (feature-batch §9): approve/reject pending
/// rows. Reads go through the admin RLS policies in 050. Rendered via
/// [AdminReviewsCubit] (audit 2026-09-13) — the page no longer calls
/// the repository from its State. Body lives in [AdminReviewsView]
/// (one widget per file).
class AdminReviewsPage extends StatelessWidget {
  const AdminReviewsPage({super.key, this.cubit, this.repository})
      : assert(cubit != null || repository != null,
            'Provide either cubit or repository.');

  final AdminReviewsCubit? cubit;
  final AdminReviewsPort? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminReviewsCubit>(
      // The router always injects [repository] (or a [cubit] in tests) —
      // the view never service-locates (audit DIP: no getIt in views).
      create: (_) =>
          (cubit ?? AdminReviewsCubit(repository: repository!))..load(),
      child: const AdminReviewsView(),
    );
  }
}
