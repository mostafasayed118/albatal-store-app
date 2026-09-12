import 'package:flutter/material.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/app_image.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/logger.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/repositories/admin_repository.dart';

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
  });
  final String productId;
  final AdminRepository repository;
  final StorageService storage;

  @override
  State<AdminImageManagerPage> createState() => _AdminImageManagerPageState();
}

class _AdminImageManagerPageState extends State<AdminImageManagerPage> {
  List<String> _paths = [];
  bool _loading = true;
  String? _error;
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
        // Admin-only, intentionally unlocalized.
        showConfirmation(context, confirmation ?? 'Images updated');
      },
      failure: (error) {
        Log.e('Admin image save failed', error: error);
        showFloatingError(context, error.message);
      },
    );
  }

  Future<void> _uploadImage() async {
    // In production this would use image_picker; here we simulate an upload
    // with dummy bytes so the StorageService + adminSetProductImages path
    // is exercised and verifiable in tests.
    setState(() => _uploading = true);
    try {
      final fileName = 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Dummy 1x1 JPEG bytes (SOI + EOI) — sufficient for storage API contract.
      final bytes = <int>[0xFF, 0xD8, 0xFF, 0xD9];
      final storagePath = await widget.storage.uploadProductImage(
        widget.productId,
        bytes,
        fileName,
        'image/jpeg',
      );
      final next = [..._paths, storagePath];
      final saveResult =
          await widget.repository.adminSetProductImages(widget.productId, next);
      if (!mounted) return;
      if (saveResult case Failure(:final error)) {
        setState(() => _uploading = false);
        showFloatingError(context, error.message);
        return;
      }
      setState(() {
        _paths = next;
        _uploading = false;
      });
      // Admin-only, intentionally unlocalized.
      showConfirmation(context, 'Image uploaded');
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showFloatingError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      Log.e('Admin image upload failed', error: e);
      // Admin-only, intentionally unlocalized.
      showFloatingError(context, 'Upload failed. Please try again.');
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
      // Admin-only, intentionally unlocalized: the delete-confirm copy below
      // (no ARB keys; the storefront stays localized).
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete image?'),
        content: const Text(
            'This removes the image from the product gallery on the store.'),
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
            child: const Text('Delete'),
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        // Admin-only, intentionally unlocalized.
                        AppButton(label: 'Retry', onPressed: _loadImages),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _uploading
                          ? const Center(child: CircularProgressIndicator())
                          : AppButton(
                              // Admin-only, intentionally unlocalized.
                              label: 'Upload Image',
                              icon: Icons.upload,
                              onPressed: _uploadImage,
                            ),
                    ),
                    Expanded(
                      child: _paths.isEmpty
                          ? FeedbackView(
                              type: FeedbackViewType.empty,
                              // Admin-only, intentionally unlocalized.
                              title: 'No images yet',
                              body:
                                  'Upload the first image so the product has a gallery on the store.',
                              actionLabel: 'Upload Image',
                              onAction: _uploadImage,
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                              itemCount: _paths.length,
                              itemBuilder: (ctx, i) {
                                final path = _paths[i];
                                String url;
                                try {
                                  url = widget.storage.getProductImageUrl(path);
                                } catch (_) {
                                  url = path;
                                }
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Real network image once CDN cache
                                      // headers land; url kept for tooltip.
                                      AppImage(
                                        source: url,
                                        fit: BoxFit.cover,
                                        placeholder: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.image, size: 40),
                                            const SizedBox(height: 8),
                                            Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .symmetric(horizontal: 8),
                                              child: Text(
                                                path.split('/').last,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _IconBtn(
                                              icon: Icons.arrow_upward,
                                              onTap: i == 0
                                                  ? null
                                                  : () => _move(i, i - 1),
                                            ),
                                            _IconBtn(
                                              icon: Icons.arrow_downward,
                                              onTap: i == _paths.length - 1
                                                  ? null
                                                  : () => _move(i, i + 1),
                                            ),
                                            _IconBtn(
                                              icon: Icons.delete,
                                              onTap: () => _delete(i),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

final class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scrim,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppColors.white),
        ),
      ),
    );
  }
}
