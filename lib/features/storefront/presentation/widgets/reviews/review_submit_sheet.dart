import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../../shared/services/image_compressor.dart';
import '../../cubit/reviews_cubit.dart';

/// Review submit bottom sheet — extracted from `reviews_section.dart`
/// verbatim (was private `_ReviewSubmitSheet`).
final class ReviewSubmitSheet extends StatefulWidget {
  const ReviewSubmitSheet({super.key, this.imageCompressor});

  final ImageCompressor? imageCompressor;

  @override
  State<ReviewSubmitSheet> createState() => ReviewSubmitSheetState();
}

/// Public state so widget tests can drive the form if needed.
/// Not part of the public API contract — prefer pumping
/// [ReviewSubmitSheet].
final class ReviewSubmitSheetState extends State<ReviewSubmitSheet> {
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
          } else {
            // Audit 2026-09-19 (sweep part 32): every other failure used to fall
            // through here with NO feedback at all. Show localized retry copy
            // instead of the repository's English message.
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(l.failureSave),
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
