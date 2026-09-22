import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../shared/components/app_card.dart';
import '../../../../../shared/components/app_image.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../../domain/entities/product_review.dart';

/// Review tile body — extracted from `reviews_section.dart` verbatim
/// (was private `_ReviewTileBody`).
final class ReviewTileBody extends StatelessWidget {
  const ReviewTileBody({super.key, required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(review.authorName,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Text(
                  DateFormat('d MMM y', l.localeName).format(review.createdAt),
                  style: TextStyle(color: scheme.outline, fontSize: 12),
                ),
              ],
            ),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: scheme.secondary,
                ),
              ),
            ),
            if (review.text.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6),
                child: Text(review.text),
              ),
            if (review.photoUrl != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  // Bounded + disk-cached decode: the thumbnail is a
                  // 120px box, never the full-resolution upload
                  // (audit 2026-09-13 perf).
                  child: AppImage(
                    source: review.photoUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                    cacheHeight: 240,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
