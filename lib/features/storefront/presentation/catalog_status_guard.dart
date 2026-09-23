import 'package:flutter/material.dart';

import '../../../shared/components/feedback_view.dart';
import '../../../shared/widgets/skeleton_loaders.dart';
import 'cubit/catalog_cubit.dart';
import 'widgets/offline_catalog_view.dart';

/// loading/initial/offline/error guards shared by Home and Catalog (audit
/// 2026-09-21 duplication cluster: byte-identical branching lived in both
/// pages and would diverge the first time one changes). Returns null when
/// the state is READY — the caller then renders its own content.
Widget? catalogStatusGuard(CatalogState state, CatalogCubit cubit) {
  if (state.status == CatalogStatus.loading ||
      state.status == CatalogStatus.initial) {
    return const CatalogSkeleton();
  }
  if (state.status == CatalogStatus.error) {
    // Task #8: offline + cold cache is an offline notice, not an error;
    // reserve the FeedbackView for real failures.
    if (state.isOffline) {
      return OfflineCatalogView(onRetry: cubit.load);
    }
    return FeedbackView(type: FeedbackViewType.error, onAction: cubit.load);
  }
  return null;
}
