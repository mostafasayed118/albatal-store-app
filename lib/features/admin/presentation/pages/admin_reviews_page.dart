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
class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key, this.cubit, this.repository})
      : assert(cubit != null || repository != null,
            'Provide either cubit or repository.');

  final AdminReviewsCubit? cubit;
  final AdminReviewsPort? repository;

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  late final AdminReviewsCubit _cubit;
  bool _ownsCubit = false;

  @override
  void initState() {
    super.initState();
    final injected = widget.cubit;
    _cubit = injected ?? AdminReviewsCubit(repository: widget.repository!);
    _ownsCubit = injected == null;
    _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminReviewsCubit>.value(
      value: _cubit,
      // The router always injects [repository] (or a [cubit] in tests) —
      // the view never service-locates (audit DIP: no getIt in views).
      child: const AdminReviewsView(),
    );
  }
}
