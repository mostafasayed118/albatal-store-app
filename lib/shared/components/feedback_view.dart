import 'package:flutter/material.dart';

import '../extensions/build_context_x.dart';
import 'app_button.dart';

enum FeedbackViewType { loading, empty, error }

/// Single status view for loading / empty / error states (UX-039).
///
/// Replaces the old `FeedbackView` + `EmptyStateView` pair: every state uses
/// the same centered icon + copy + optional CTA layout, so screens speak one
/// visual language. Loading animates (a real spinner — a frozen hourglass
/// reads as a hung app); empty/error can carry bespoke copy via the optional
/// overrides (the defaults come from l10n). Empty-state CTAs render outline,
/// error CTAs filled.
final class FeedbackView extends StatelessWidget {
  const FeedbackView({
    super.key,
    required this.type,
    this.onAction,
    this.icon,
    this.title,
    this.body,
    this.actionLabel,
    this.iconSize = 64,
  });

  final FeedbackViewType type;

  /// Invoked by the CTA (shown when the resolved action copy is non-empty).
  final VoidCallback? onAction;

  /// Overrides the type's default icon (ignored for [FeedbackViewType.loading]).
  final IconData? icon;

  /// Overrides the type's default title copy.
  final String? title;

  /// Overrides the type's default body/subtitle copy.
  final String? body;

  /// Overrides the type's default action-label copy.
  final String? actionLabel;

  /// Diameter of the icon / spinner slot.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolved = switch (type) {
      FeedbackViewType.loading => (
          icon: null,
          title: title ?? l10n.loading,
          body: '',
          action: ''
        ),
      FeedbackViewType.empty => (
          icon: icon ?? Icons.inventory_2_outlined,
          title: title ?? l10n.emptyTitle,
          body: body ?? l10n.emptyBody,
          action: actionLabel ?? l10n.returnHome
        ),
      FeedbackViewType.error => (
          icon: icon ?? Icons.error_outline_rounded,
          title: title ?? l10n.errorTitle,
          body: body ?? '',
          action: actionLabel ?? l10n.retry
        ),
    };
    final view = Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: iconSize,
          width: iconSize,
          child: resolved.icon == null
              ? const CircularProgressIndicator(strokeWidth: 3)
              : Icon(resolved.icon,
                  size: iconSize, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 16),
        Text(resolved.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        if (resolved.body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(resolved.body, textAlign: TextAlign.center)
        ],
        if (resolved.action.isNotEmpty && onAction != null) ...[
          const SizedBox(height: 24),
          AppButton(
            label: resolved.action,
            style: type == FeedbackViewType.empty
                ? AppButtonStyle.outline
                : AppButtonStyle.primary,
            onPressed: onAction,
          )
        ],
      ]),
    ));
    // Loading announces itself to screen readers; static content does not
    // need a live region.
    if (type == FeedbackViewType.loading) {
      return Semantics(liveRegion: true, label: l10n.loading, child: view);
    }
    return view;
  }
}
