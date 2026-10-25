import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../../../shared/components/app_card.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../../../shared/l10n/money_copy.dart';
import '../../../../shared/utils/app_date_formats.dart';
import '../../domain/entities/instapay_proof.dart';
import '../../domain/repositories/admin_instapay_port.dart';
import '../cubit/admin_instapay_cubit.dart';
import '../widgets/admin_error_feedback.dart';
import '../widgets/dialog_controllers.dart';

/// Admin InstaPay proof review: list pending transfer proofs, preview the
/// screenshot, then approve or reject.
///
/// Closes the verified end-to-end break where customers could submit proofs
/// but no admin surface could act on them. Reads come from
/// `admin_list_instapay_proofs()` (migration 082); writes go through the
/// `instapay-review` edge function, which owns the transaction that marks the
/// payment successful and the order paid.
///
/// The router resolves [repository] at the composition root (audit P1);
/// widget tests inject a [cubit] and/or a fake port. A cubit-only injection
/// still renders the queue — only proof thumbnails degrade to the missing
/// placeholder without a port.
class AdminInstapayReviewsPage extends StatelessWidget {
  const AdminInstapayReviewsPage({
    super.key,
    this.cubit,
    this.repository,
  }) : assert(cubit != null || repository != null,
            'Provide either cubit or repository.');

  final AdminInstapayCubit? cubit;
  final AdminInstapayPort? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminInstapayCubit>(
      create: (_) =>
          (cubit ?? AdminInstapayCubit(repository: repository!))..load(),
      child: _AdminInstapayView(repository: repository),
    );
  }
}

final class _AdminInstapayView extends StatefulWidget {
  const _AdminInstapayView({this.repository});

  final AdminInstapayPort? repository;

  @override
  State<_AdminInstapayView> createState() => _AdminInstapayViewState();
}

class _AdminInstapayViewState extends State<_AdminInstapayView>
    with DialogControllers {
  @override
  void dispose() {
    // Reject dialogs own a note TextField; free its controller with the page,
    // never while the dialog's exit animation still has it mounted.
    disposeDialogControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminInstapayTitle)),
      body: BlocListener<AdminInstapayCubit, AdminInstapayState>(
        listenWhen: (previous, current) =>
            current.lastAction != null &&
            current.lastAction != previous.lastAction,
        listener: (context, state) {
          final action = state.lastAction;
          if (action == null) return;
          if (action.failed) {
            showFloatingError(
              context,
              _reviewFailureText(context, state.errorCode),
            );
          } else {
            showConfirmation(
              context,
              action.approve
                  ? l.adminInstapayApproved
                  : l.adminInstapayRejected,
            );
          }
        },
        child: BlocBuilder<AdminInstapayCubit, AdminInstapayState>(
          builder: (context, state) {
            if (state.status == AdminInstapayStatus.initial ||
                state.status == AdminInstapayStatus.loading) {
              return const FeedbackView(type: FeedbackViewType.loading);
            }
            if (state.status == AdminInstapayStatus.error) {
              return AdminErrorFeedback(
                // InstaPay codes are feature-owned; resolve them here so the
                // English diagnosis message never reaches the admin.
                errorMessage: _loadFailureText(
                    context, state.errorCode, state.errorMessage),
                fallback: l.adminInstapayLoadFailed,
                title: l.adminInstapayLoadFailed,
                onRetry: () => context.read<AdminInstapayCubit>().load(),
              );
            }
            return RefreshIndicator(
              onRefresh: () => context.read<AdminInstapayCubit>().load(),
              child: state.proofs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.all(32),
                          child: FeedbackView(
                            type: FeedbackViewType.empty,
                            icon: Icons.account_balance_outlined,
                            title: l.adminInstapayEmpty,
                            body: l.adminInstapaySubtitle,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsetsDirectional.all(16),
                      itemCount: state.proofs.length + 1,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding:
                                const EdgeInsetsDirectional.only(bottom: 8),
                            child: Text(
                              l.adminInstapaySubtitle,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }
                        final proof = state.proofs[i - 1];
                        return _ProofCard(
                          proof: proof,
                          repository: widget.repository,
                          reviewing: state.isReviewing(proof.proofId),
                          onApprove: () => _confirmApprove(proof),
                          onReject: () => _confirmReject(proof),
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmApprove(InstapayProof proof) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.adminInstapayApprove),
          content: Text(context.l10n.adminInstapayConfirmApprove),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<AdminInstapayCubit>().approve(proof.proofId);
              },
              child: Text(context.l10n.adminInstapayApprove),
            ),
          ],
        ),
      );

  Future<void> _confirmReject(InstapayProof proof) {
    final noteController = newDialogController();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.adminInstapayReject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.adminInstapayConfirmReject),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.l10n.adminInstapayNote,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final note = noteController.text.trim();
              Navigator.pop(dialogContext);
              context.read<AdminInstapayCubit>().reject(
                    proof.proofId,
                    note: note.isEmpty ? null : note,
                  );
            },
            child: Text(context.l10n.adminInstapayReject),
          ),
        ],
      ),
    );
  }
}

/// One queue row: payer, order handle, total, reference, submission time,
/// proof preview and the two review actions.
final class _ProofCard extends StatelessWidget {
  const _ProofCard({
    required this.proof,
    required this.repository,
    required this.reviewing,
    required this.onApprove,
    required this.onReject,
  });

  final InstapayProof proof;
  final AdminInstapayPort? repository;
  final bool reviewing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AppCard(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProofThumbnail(proof: proof, repository: repository),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proof.customerName,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l.adminInstapayOrder} #${proof.shortOrderId}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        moneyText(l, proof.total),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (proof.reference != null) ...[
              _LabeledValue(
                label: l.adminInstapayReference,
                value: proof.reference!,
              ),
              const SizedBox(height: 8),
            ],
            _LabeledValue(
              label: l.adminInstapaySubmittedAt,
              value: AppDateFormats.dayMonthYearTime(l.localeName)
                  .format(proof.createdAt),
            ),
            const SizedBox(height: 12),
            if (reviewing)
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: EdgeInsetsDirectional.all(8),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close),
                      label: Text(l.adminInstapayReject),
                    ),
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check),
                      label: Text(l.adminInstapayApprove),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two-line label/value pair that survives large text scales and RTL: no
/// shared [Row], so a long reference wraps instead of overflowing.
final class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Proof preview: loading spinner, signed-URL image, or a distinct
/// "no file / could not load" placeholder.
final class _ProofThumbnail extends StatefulWidget {
  const _ProofThumbnail({required this.proof, required this.repository});

  final InstapayProof proof;
  final AdminInstapayPort? repository;

  @override
  State<_ProofThumbnail> createState() => _ProofThumbnailState();
}

class _ProofThumbnailState extends State<_ProofThumbnail> {
  Future<Result<String>>? _url;

  @override
  void didUpdateWidget(covariant _ProofThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A row keeps its proof id while the queue refreshes, but a re-submitted
    // proof changes the path; mint a new URL rather than show a stale image.
    if (oldWidget.proof.proofId != widget.proof.proofId ||
        oldWidget.proof.storagePath != widget.proof.storagePath) {
      _url = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repository = widget.repository;
    if (!widget.proof.hasProofFile || repository == null) {
      return _Placeholder(
        icon: Icons.receipt_long_outlined,
        tooltip: l.adminInstapayProofMissing,
        semanticLabel: l.adminInstapayProofMissing,
      );
    }
    final future = _url ??= repository.signedProofUrl(widget.proof.storagePath);
    return SizedBox(
      height: 72,
      width: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Result<String>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _Placeholder(loading: true);
            }
            final result = snapshot.data;
            final url = result is Success<String> ? result.value : null;
            if (url == null) {
              return _Placeholder(
                icon: Icons.broken_image_outlined,
                tooltip: l.adminInstapayProofMissing,
              );
            }
            return Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const _Placeholder(loading: true),
              errorBuilder: (context, error, stackTrace) => _Placeholder(
                icon: Icons.broken_image_outlined,
                tooltip: l.adminInstapayProofMissing,
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _Placeholder extends StatelessWidget {
  const _Placeholder({
    this.icon,
    this.tooltip,
    this.semanticLabel,
    this.loading = false,
  });

  final IconData? icon;
  final String? tooltip;
  final String? semanticLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = Container(
      height: 72,
      width: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              icon ?? Icons.image_outlined,
              color: scheme.onSurfaceVariant,
            ),
    );
    if (tooltip == null) return child;
    return Tooltip(
      message: tooltip!,
      child: Semantics(label: semanticLabel, child: child),
    );
  }
}

/// Review failures are feature-coded; the only one with dedicated local copy
/// is the admin gate. Everything else ("already reviewed", "payment no longer
/// pending", transport) collapses to the retry copy — the refreshed queue
/// shows the current truth.
String _reviewFailureText(BuildContext context, String? code) {
  final l = context.l10n;
  return code == kAdminInstapayAccessDenied
      ? l.adminFailureAccessDenied
      : l.adminInstapayReviewFailed;
}

/// Resolves the queue-load failure: the feature's own code localizes to the
/// queue title, any shared code goes through [failureText], and only the
/// remaining server prose is shown verbatim.
String _loadFailureText(BuildContext context, String? code, String? message) {
  final l = context.l10n;
  if (code == kAdminInstapayLoadFailed) return l.adminInstapayLoadFailed;
  return failureText(
    l,
    code: code,
    message: message,
    fallback: l.adminInstapayLoadFailed,
  );
}
