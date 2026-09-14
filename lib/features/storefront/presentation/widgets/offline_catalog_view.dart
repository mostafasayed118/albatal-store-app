import 'package:flutter/material.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';

/// Friendly offline notice for the catalog surfaces (Task #8).
///
/// Shown in place of the generic error FeedbackView when the
/// ConnectivityGate reported offline and the persistent catalog cache
/// was cold — an offline miss is not a real failure, so the copy points
/// at the connection (existing `offlineBannerMessage` / `errorBody` /
/// `retry` ARB keys; no new strings) and [onRetry] re-runs the load.
final class OfflineCatalogView extends StatelessWidget {
  const OfflineCatalogView({super.key, required this.onRetry});

  /// Re-runs the catalog/details load (the retry also re-probes the
  /// gate via the load path); maps to the outline empty-state CTA.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FeedbackView(
      key: const ValueKey('offlineCatalogView'),
      type: FeedbackViewType.empty,
      icon: Icons.wifi_off_outlined,
      title: l.offlineBannerMessage,
      body: l.errorBody,
      actionLabel: l.retry,
      onAction: onRetry,
    );
  }
}
