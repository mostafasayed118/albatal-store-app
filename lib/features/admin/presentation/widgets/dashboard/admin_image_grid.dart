import 'package:flutter/material.dart';

import '../../../../../shared/components/app_image.dart';
import '../../../../../shared/services/storage_service.dart';
import 'admin_image_icon_btn.dart';

/// Grid of product images with reorder/delete overlays.
///
/// Extracted from `admin_image_manager_page.dart` (private `_ImageGrid`).
class AdminImageGrid extends StatelessWidget {
  const AdminImageGrid({
    super.key,
    required this.paths,
    required this.storage,
    required this.onMove,
    required this.onDelete,
  });
  final List<String> paths;
  final StorageService storage;
  final void Function(int from, int to) onMove;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: paths.length,
      itemBuilder: (ctx, i) {
        final path = paths[i];
        // Ask for the budget the tile decodes at (see the AppImage below):
        // this page was the last surface still pulling the full upload
        // (audit P0-4). Falls back to the stored path when the client is
        // not available.
        String url;
        try {
          url = storage.getProductImageUrlForWidth(
            path,
            StorageService.gridImageWidth,
          );
        } catch (_) {
          url = path;
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Bounded at BOTH ends: the url above requests a 420 render
              // and this decodes at 420, so a grid cell never touches the
              // full-resolution bitmap (audit 2026-09-13 perf, P0-4).
              AppImage(
                source: url,
                fit: BoxFit.cover,
                cacheWidth: 420,
                cacheHeight: 420,
                placeholder: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image, size: 40),
                    const SizedBox(height: 8),
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.symmetric(horizontal: 8),
                      child: Text(
                        path.split('/').last,
                        style: Theme.of(context).textTheme.bodySmall,
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
                    AdminImageIconBtn(
                      icon: Icons.arrow_upward,
                      onTap: i == 0 ? null : () => onMove(i, i - 1),
                    ),
                    AdminImageIconBtn(
                      icon: Icons.arrow_downward,
                      onTap:
                          i == paths.length - 1 ? null : () => onMove(i, i + 1),
                    ),
                    AdminImageIconBtn(
                      icon: Icons.delete,
                      onTap: () => onDelete(i),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
