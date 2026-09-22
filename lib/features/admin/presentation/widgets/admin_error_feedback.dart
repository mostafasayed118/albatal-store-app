import 'package:flutter/material.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';

/// The standard admin failure surface (audit 2026-09-21, P2 dedupe):
/// [FeedbackView] in its error variant whose body resolves the
/// failure-code protocol — a coded failure localizes via [failureText],
/// an uncoded one is server prose shown verbatim, and with neither the
/// [fallback] copy shows.
///
/// Ten near-verbatim copies across the admin pages collapsed into this
/// widget; the only real variation was the retry callback (plus optional
/// title / action-label / fallback overrides on four of them). The
/// order-detail "not found" surface is deliberately NOT this widget: it
/// has no failure-code body at all.
final class AdminErrorFeedback extends StatelessWidget {
  const AdminErrorFeedback({
    super.key,
    this.errorCode,
    this.errorMessage,
    this.fallback,
    this.title,
    this.actionLabel,
    required this.onRetry,
  });

  /// Machine failure class (see `failure_codes.dart`) — localizes the body.
  final String? errorCode;

  /// Raw diagnosis message, shown verbatim only when [errorCode] is null
  /// (server-authored prose per the P1 ruling).
  final String? errorMessage;

  /// Localized body copy when neither [errorCode] nor [errorMessage]
  /// resolves. Defaults to `l10n.errorTitle`.
  final String? fallback;

  /// Overrides the default localized error title.
  final String? title;

  /// Overrides the default localized Retry CTA label.
  final String? actionLabel;

  /// Invoked by the CTA — the caller's reload/retry path.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FeedbackView(
      type: FeedbackViewType.error,
      title: title,
      body: failureText(l,
          code: errorCode,
          message: errorMessage,
          fallback: fallback ?? l.errorTitle),
      actionLabel: actionLabel,
      onAction: onRetry,
    );
  }
}
