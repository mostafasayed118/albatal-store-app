import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../../shared/services/image_compressor.dart';
import '../../cubit/reviews_cubit.dart';
import 'review_submit_sheet.dart';
import 'reviews_inline_list.dart';

/// Loaded reviews body — extracted from `reviews_section.dart` verbatim
/// (was private `_ReviewsView`).
final class ReviewsView extends StatelessWidget {
  const ReviewsView({super.key, this.imageCompressor});

  final ImageCompressor? imageCompressor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<ReviewsCubit, ReviewsState>(
      builder: (context, state) {
        if (state.status == ReviewsStatus.unavailable ||
            state.status == ReviewsStatus.initial) {
          return const SizedBox.shrink();
        }
        if (state.status == ReviewsStatus.error) {
          // A failed fetch must not vanish silently: show compact error copy
          // with a retry that refetches the same product.
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: 18, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.errorTitle,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                TextButton(
                  onPressed: () => context.read<ReviewsCubit>().reload(),
                  child: Text(l.retry),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.customerReviews,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: () => _showSubmitSheet(context, imageCompressor),
                  child: Text(l.writeReview),
                ),
              ],
            ),
            if (state.status == ReviewsStatus.loading)
              const Padding(
                padding: EdgeInsetsDirectional.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.reviews.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                child: Text(l.noReviewsYet,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline)),
              )
            else
              // Virtualized (audit 2026-09-14 P0-4): the old
              // `...reviews.map` spread built every tile up front; the
              // builder recycles tiles and caps the inline list at 10
              // with a Show-all sheet for the rest.
              ReviewsInlineList(reviews: state.reviews),
          ],
        );
      },
    );
  }

  void _showSubmitSheet(BuildContext context, ImageCompressor? compressor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider<ReviewsCubit>.value(
        value: context.read<ReviewsCubit>(),
        child: ReviewSubmitSheet(imageCompressor: compressor),
      ),
    );
  }
}
