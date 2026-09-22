import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/app_card.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/repositories/admin_reviews_port.dart';
import '../cubit/admin_reviews_cubit.dart';
import '../widgets/admin_error_feedback.dart';

/// Admin review moderation (feature-batch §9): approve/reject pending
/// rows. Reads go through the admin RLS policies in 050. Rendered via
/// [AdminReviewsCubit] (audit 2026-09-13) — the page no longer calls
/// the repository from its State.
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
      child: const _AdminReviewsView(),
    );
  }
}

final class _AdminReviewsView extends StatelessWidget {
  const _AdminReviewsView();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.reviewModeration)),
      body: BlocBuilder<AdminReviewsCubit, AdminReviewsState>(
        builder: (context, state) {
          if (state.status == AdminReviewsStatus.loading) {
            return const FeedbackView(type: FeedbackViewType.loading);
          }
          if (state.status == AdminReviewsStatus.error) {
            return AdminErrorFeedback(
              errorCode: state.errorCode,
              errorMessage: state.errorMessage,
              onRetry: () => context.read<AdminReviewsCubit>().load(),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<AdminReviewsCubit>().load(),
            child: state.pending.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.all(32),
                      child: Center(child: Text(l.noReviewsYet)),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsetsDirectional.all(16),
                    itemCount: state.pending.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = state.pending[i];
                      return AppCard(
                        child: ListTile(
                          title: Text(r.text),
                          subtitle: Text('${r.product} · ${'★' * r.rating}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l.reviewApprove,
                                onPressed: () => context
                                    .read<AdminReviewsCubit>()
                                    .moderate(r.id, approve: true),
                                icon: const Icon(Icons.check),
                              ),
                              IconButton(
                                tooltip: l.reviewReject,
                                onPressed: () => context
                                    .read<AdminReviewsCubit>()
                                    .moderate(r.id, approve: false),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
