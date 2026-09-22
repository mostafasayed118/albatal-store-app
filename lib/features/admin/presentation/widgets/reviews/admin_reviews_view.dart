import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/components/app_card.dart';
import '../../../../../shared/components/feedback_view.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../admin_error_feedback.dart';
import '../../cubit/admin_reviews_cubit.dart';

/// Pending-review moderation list — extracted from
/// `admin_reviews_page.dart` verbatim (was private `_AdminReviewsView`).
final class AdminReviewsView extends StatelessWidget {
  const AdminReviewsView({super.key});

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
