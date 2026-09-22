import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/app_error.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../../../shared/services/image_compressor.dart';
import '../../../../shared/services/logger.dart';
import '../../../../shared/services/storage_service.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/admin_error_feedback.dart';
import '../widgets/dashboard/admin_image_grid.dart';
import 'admin_image_upload_flow.dart';

export 'admin_image_upload_flow.dart' show ProductImagePicker;

Future<XFile?> defaultProductImagePick(ImageSource source) =>
    ImagePicker().pickImage(
      source: source,
      maxWidth: kMaxUploadDimension.toDouble(),
      maxHeight: kMaxUploadDimension.toDouble(),
      imageQuality: 80,
    );

/// Image manager for a single product — grid, upload, reorder, delete.
///
/// Dependencies are constructor-injected (audit P1): the router resolves
/// them at the composition root; pages never touch the locator.
class AdminImageManagerPage extends StatefulWidget {
  const AdminImageManagerPage({
    super.key,
    required this.productId,
    required this.repository,
    required this.storage,
    this.pickImage = defaultProductImagePick,
    this.imageCompressor,
  });
  final String productId;
  final AdminRepository repository;
  final StorageService storage;

  /// Gallery picker (injectable for tests).
  final ProductImagePicker pickImage;

  /// §4 compression pass; fail-open by contract, so a null injection
  /// (tests) degrades to a no-op compressor.
  final ImageCompressor? imageCompressor;

  @override
  State<AdminImageManagerPage> createState() => _AdminImageManagerPageState();
}

class _AdminImageManagerPageState extends State<AdminImageManagerPage> {
  List<String> _paths = [];
  bool _loading = true;
  String? _error;
  String? _errorCode;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await widget.repository.getProductImagePaths(widget.productId);
    if (!mounted) return;
    result.when(
      success: (paths) => setState(() {
        _paths = paths;
        _loading = false;
      }),
      failure: (error) {
        Log.e('Admin image list load failed', error: error);
        setState(() {
          _loading = false;
          _error = error.message;
          _errorCode = error.code;
        });
      },
    );
  }

  Future<void> _persistPaths(List<String> paths, {String? confirmation}) async {
    final result =
        await widget.repository.adminSetProductImages(widget.productId, paths);
    if (!mounted) return;
    result.when(
      success: (_) {
        setState(() => _paths = List.of(paths));
        // Confirm only what the repository saved — and say what happened
        // (an "Images updated" after a delete reads wrong).
        showConfirmation(
            context, confirmation ?? context.l10n.adminImagesUpdated);
      },
      failure: (error) {
        Log.e('Admin image save failed', error: error);
        showFloatingError(
          context,
          failureText(context.l10n,
              code: error.code,
              message: error.message,
              fallback: context.l10n.errorTitle),
        );
      },
    );
  }

  Future<void> _uploadImage() async {
    setState(() => _uploading = true);
    try {
      final outcome = await runAdminImageUpload(
        productId: widget.productId,
        pickImage: widget.pickImage,
        compressor: widget.imageCompressor,
        storage: widget.storage,
        repository: widget.repository,
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      switch (outcome) {
        case AdminUploadCancelled():
          break;
        case AdminUploadSuccess(:final paths):
          setState(() => _paths = paths);
          showConfirmation(context, context.l10n.adminImageUploaded);
        case AdminUploadError(:final l10nKey, :final error):
          if (error != null) {
            showFloatingError(
              context,
              failureText(context.l10n,
                  code: error.code,
                  message: error.message,
                  fallback: context.l10n.errorTitle),
            );
          } else if (l10nKey == 'adminImageFileEmpty') {
            showFloatingError(context, context.l10n.adminImageFileEmpty);
          } else if (l10nKey == 'adminImageUnsupportedFormat') {
            showFloatingError(
                context, context.l10n.adminImageUnsupportedFormat);
          } else if (l10nKey == 'adminImageTooLarge') {
            showFloatingError(context, context.l10n.adminImageTooLarge);
          } else {
            showFloatingError(context, context.l10n.adminImageUploadFailed);
          }
      }
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showFloatingError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      Log.e('Admin image upload failed', error: e);
      showFloatingError(context, context.l10n.adminImageUploadFailed);
    }
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _paths.length) return;
    hapticTap();
    final next = List<String>.of(_paths);
    final item = next.removeAt(from);
    next.insert(to, item);
    // sort_order is implicit by list order passed to adminSetProductImages.
    _persistPaths(next);
  }

  /// A single tap on the small overlay icon must not delete an image:
  /// confirm first, then confirm the outcome.
  Future<void> _delete(int index) async {
    hapticWarning();
    // Let the tapped tile's frame finish rendering before pushing the
    // dialog (same slow-device guard used by the other admin dialogs).
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.adminDeleteImageTitle),
        content: Text(context.l10n.adminDeleteImageBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = List<String>.of(_paths)..removeAt(index);
    await _persistPaths(next, confirmation: context.l10n.imageRemoved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.productImages)),
      body: _loading
          ? const FeedbackView(type: FeedbackViewType.loading)
          : _error != null
              ? AdminErrorFeedback(
                  errorCode: _errorCode,
                  errorMessage: _error,
                  title: l10n.adminImagesLoadFailed,
                  actionLabel: l10n.retry,
                  onRetry: _loadImages,
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _uploading
                          ? const Center(child: CircularProgressIndicator())
                          : AppButton(
                              label: l10n.adminUploadImage,
                              icon: Icons.upload,
                              onPressed: _uploadImage,
                            ),
                    ),
                    Expanded(
                      child: _paths.isEmpty
                          ? FeedbackView(
                              type: FeedbackViewType.empty,
                              title: l10n.adminNoImages,
                              body:
                                  'Upload the first image so the product has a gallery on the store.',
                              actionLabel: l10n.adminUploadImage,
                              onAction: _uploadImage,
                            )
                          : AdminImageGrid(
                              paths: _paths,
                              storage: widget.storage,
                              onMove: _move,
                              onDelete: _delete,
                            ),
                    ),
                  ],
                ),
    );
  }
}
