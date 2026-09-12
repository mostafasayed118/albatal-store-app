import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/image_compressor.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../cubit/reviews_cubit.dart';

/// Approved customer reviews + submit affordance for the details page
/// (feature-batch §9).
///
/// The repository resolves from the locator when registered; when it is
/// not (pre-DI widget tests) the section renders nothing so the details
/// page never breaks.
class ReviewsSection extends StatelessWidget {
  const ReviewsSection({super.key, required this.productId, this.repository});

  final String productId;
  final ReviewsRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReviewsCubit>(
      create: (_) {
        final repo = repository ??
            (getIt.isRegistered<ReviewsRepository>()
                ? getIt<ReviewsRepository>()
                : null);
        return ReviewsCubit(repository: repo)..load(productId);
      },
      child: const _ReviewsView(),
    );
  }
}

final class _ReviewsView extends StatelessWidget {
  const _ReviewsView();

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
                  onPressed: () => _showSubmitSheet(context),
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
              ...state.reviews.map((r) => _ReviewTile(review: r)),
          ],
        );
      },
    );
  }

  void _showSubmitSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider<ReviewsCubit>.value(
        value: context.read<ReviewsCubit>(),
        child: const _ReviewSubmitSheet(),
      ),
    );
  }
}

final class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.cardRadius,
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
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
                  child: Image.network(
                    review.photoUrl!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _ReviewSubmitSheet extends StatefulWidget {
  const _ReviewSubmitSheet();

  @override
  State<_ReviewSubmitSheet> createState() => _ReviewSubmitSheetState();
}

final class _ReviewSubmitSheetState extends State<_ReviewSubmitSheet> {
  int _rating = 5;
  final _textController = TextEditingController();
  XFile? _photo;
  bool _processingPhoto = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() => _processingPhoto = true);
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (xfile == null) return;
      // §4 enforcement pass before the upload path.
      final bytes = await xfile.readAsBytes();
      await getIt<ImageCompressor>().compress(bytes);
      setState(() => _photo = xfile);
    } on Exception {
      // picker unavailable (web/tests) — text-only review still works
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: BlocConsumer<ReviewsCubit, ReviewsState>(
        listener: (context, state) {
          if (state.submitting || state.submitMessage == null) return;
          if (state.submitMessage == kReviewBuyRequiredCode) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(l.reviewBuyRequired),
            ));
          } else if (state.submitMessage == kReviewUnavailableCode) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(l.reviewUnavailable),
            ));
          }
        },
        builder: (context, state) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.writeReview, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                5,
                (i) => IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(hintText: l.reviewPlaceholder),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _processingPhoto ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(_photo == null
                      ? l.reviewAddPhoto
                      : l.reviewPhotoAdded),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: state.submitting
                      ? null
                      : () {
                          context.read<ReviewsCubit>().submit(
                                rating: _rating,
                                text: _textController.text,
                                photoPath: _photo?.path,
                              );
                          Navigator.of(context).pop();
                        },
                  child: Text(l.reviewSubmit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
