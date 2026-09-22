import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../../domain/entities/product_review.dart';
import 'review_tile.dart';

/// Inline review list: first 10 recycled via builder + Show-all sheet.
///
/// Caps the inline column the details page renders — the old spread built
/// every tile (and star row) up front. The sheet reuses the same tile so
/// long review histories scroll virtualized instead of overflowing the
/// details column.
///
/// Extracted from `reviews_section.dart` verbatim (was private
/// `_ReviewsInlineList`).
final class ReviewsInlineList extends StatelessWidget {
  const ReviewsInlineList({super.key, required this.reviews});

  final List<ProductReview> reviews;

  static const _inlineCap = 10;

  @override
  Widget build(BuildContext context) {
    final visible = reviews.take(_inlineCap).toList();
    final remaining = reviews.length - visible.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audit fix (shrinkWrap): a shrinkWrap ListView.builder recycles
        // nothing — it lays out every tile AND pays the nested-scrollable
        // measurement pass inside the details page's ListView. The cap is
        // 10 tiles, so a plain Column builds the same widgets cheaper and
        // keeps long histories virtualized in the Show-all sheet below.
        ...List.generate(
          visible.length,
          (i) => ReviewTile(review: visible[i]),
        ),
        if (remaining > 0)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => _showAllSheet(context),
              child: Text(context.l10n.showAllReviews(remaining)),
            ),
          ),
      ],
    );
  }

  void _showAllSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          itemCount: reviews.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: ReviewTile(review: reviews[i]),
          ),
        ),
      ),
    );
  }
}
