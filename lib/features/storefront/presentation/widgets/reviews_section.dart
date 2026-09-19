import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../shared/components/app_image.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/image_compressor.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../cubit/reviews_cubit.dart';

/// Approved customer reviews + submit affordance for the details page
/// (feature-batch §9).
///
/// The repository is constructor-injected (audit P1) — the details page
/// hands down what the router resolved at the composition root. When it
/// is null (pre-DI widget tests) the section renders nothing so the
/// details page never breaks.
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
      child: _ReviewsView(imageCompressor: imageCompressor),
    );
  }
}

final class _ReviewsView extends StatelessWidget {
  const _ReviewsView({this.imageCompressor});

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
              _ReviewsInlineList(reviews: state.reviews),
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
        child: _ReviewSubmitSheet(imageCompressor: compressor),
      ),
    );
  }
}

final class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: _ReviewTileBody(review: review));
  }
}

final class _ReviewTileBody extends StatelessWidget {
  const _ReviewTileBody({required this.review});

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

/// Inline review list: first 10 recycled via builder + Show-all sheet.
///
/// Caps the inline column the details page renders — the old spread built
/// every tile (and star row) up front. The sheet reuses the same tile so
/// long review histories scroll virtualized instead of overflowing the
/// details column.
final class _ReviewsInlineList extends StatelessWidget {
  const _ReviewsInlineList({required this.reviews});

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
          (i) => _ReviewTile(review: visible[i]),
        ),
        if (remaining > 0)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              // Localized copy lands with the next l10n regen (lib-only
              // scope — no .arb edits in this slice); count stays visible.
              onPressed: () => _showAllSheet(context),
              child: Text('Show all ($remaining)'),
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
            child: _ReviewTile(review: reviews[i]),
          ),
        ),
      ),
    );
  }
}

final class _ReviewSubmitSheet extends StatefulWidget {
  const _ReviewSubmitSheet({this.imageCompressor});

  final ImageCompressor? imageCompressor;

  @override
  State<_ReviewSubmitSheet> createState() => _ReviewSubmitSheetState();
}

final class _ReviewSubmitSheetState extends State<_ReviewSubmitSheet> {
  int _rating = 5;
  final _textController = TextEditingController();
  Uint8List? _photoBytes;
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
      // §4 enforcement pass before the upload path. The compressed
      // bytes ARE the upload payload — the old sheet discarded them and
      // made the repository re-read the original file synchronously
      // (audit 2026-09-13).
      final bytes = await xfile.readAsBytes();
      // Compressor is constructor-injected (composition root); a null
      // (pre-DI test) falls back to the raw bytes — the server-side
      // guard still bounds the upload.
      final compressor = widget.imageCompressor;
      final compressed =
          compressor != null ? await compressor.compress(bytes) : bytes;
      setState(() => _photoBytes = compressed);
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
                  label: Text(_photoBytes == null
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
                                photoBytes: _photoBytes,
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
