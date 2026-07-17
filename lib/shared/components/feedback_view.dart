import 'package:flutter/material.dart';

import '../extensions/build_context_x.dart';
import 'app_button.dart';

enum FeedbackViewType { loading, empty, error }

final class FeedbackView extends StatelessWidget {
  const FeedbackView({super.key, required this.type, this.onAction});

  final FeedbackViewType type;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (IconData icon, String title, String body, String? action) = switch (type) {
      FeedbackViewType.loading => (Icons.hourglass_top_rounded, l10n.loading, '', null),
      FeedbackViewType.empty => (Icons.inventory_2_outlined, l10n.emptyTitle, l10n.emptyBody, l10n.returnHome),
      FeedbackViewType.error => (Icons.error_outline_rounded, l10n.errorTitle, '', l10n.retry),
    };
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16), Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        if (body.isNotEmpty) ...[const SizedBox(height: 8), Text(body, textAlign: TextAlign.center)],
        if (action != null && onAction != null) ...[const SizedBox(height: 24), AppButton(label: action, onPressed: onAction)],
      ]),
    ));
  }
}
