import 'package:flutter/material.dart';

import '../../../domain/entities/product_review.dart';
import 'review_tile_body.dart';

/// Single review tile — extracted from `reviews_section.dart` verbatim
/// (was private `_ReviewTile`).
final class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: ReviewTileBody(review: review));
  }
}
