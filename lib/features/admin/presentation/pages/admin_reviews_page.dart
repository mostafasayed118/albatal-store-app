import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/error_l10n.dart';
import '../../domain/repositories/admin_repository.dart';
import '../cubit/admin_reviews_cubit.dart';

/// Admin review moderation (feature-batch §9): approve/reject pending
/// rows. Reads go through the admin RLS policies in 050. Rendered via
/// [AdminReviewsCubit] (audit 2026-09-13) — the page no longer calls
/// the repository from its State.
class AdminReviewsPage extends StatelessWidget {
  const AdminReviewsPage({super.key, this.cubit, this.repository});

  final AdminReviewsCubit? cubit;
  final AdminRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminReviewsCubit>(
      create: (_) => (cubit ??
          AdminReviewsCubit(repository: repository ?? getIt<AdminRepository>()))
        ..load(),
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
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == AdminReviewsStatus.error) {
            // Code-based localization (audit 2026-09-14): failures with
            // a machine code map to localized copy; unknown codes keep
            // the English fallback verbatim.
            return Center(
                child: Text(localizedErrorMessage(
                    context, state.errorMessage, code: state.errorCode) ??
                ''));
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
                      return Card(
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.cardRadius,
                          side: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                              width: 1),
                        ),
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
