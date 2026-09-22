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
            state.status == ReviewsStatus.initial ||
            state.status == ReviewsStatus.error) {
          return const SizedBox.shrink();
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
