import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/services/image_compressor.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../cubit/reviews_cubit.dart';
import 'reviews/reviews_view.dart';

/// Approved customer reviews + submit affordance for the details page
/// (feature-batch §9).
///
/// The repository is constructor-injected (audit P1) — the details page
/// hands down what the router resolved at the composition root. When it
/// is null (pre-DI widget tests) the section renders nothing so the
/// details page never breaks.
///
/// Bodies live in `reviews/` (one widget per file): [ReviewsView],
/// [ReviewTile], [ReviewTileBody], [ReviewsInlineList], [ReviewSubmitSheet].
class ReviewsSection extends StatelessWidget {
  const ReviewsSection(
      {super.key,
      required this.productId,
      this.repository,
      this.imageCompressor});

  final String productId;

  /// Reviews backend. Null renders the section as `unavailable` (hidden)
  /// via [ReviewsCubit].
  final ReviewsRepository? repository;

  /// §4 upload-image compression, resolved at the composition root. Null
  /// (pre-DI widget tests) falls back to the uncompressed bytes — the
  /// server-side guard still bounds the upload.
  final ImageCompressor? imageCompressor;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReviewsCubit>(
      create: (_) => ReviewsCubit(repository: repository)..load(productId),
      child: ReviewsView(imageCompressor: imageCompressor),
    );
  }
}
