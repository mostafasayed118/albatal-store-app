import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';

/// Full-screen photo viewer with interactive pinch-zoom (photo_view).
///
/// Opened from [ImageGallery] via a pushed route; keeps the same data
/// contract (`images` + `initialIndex` + `imageColor`). Each page is a
/// [PhotoViewGallery] item: pinch/double-tap zoom handled by photo_view,
/// page swipes switch photos. Missing sources render the same texture
/// fallback icon used across the catalog.
class ZoomGallery extends StatefulWidget {
  const ZoomGallery({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.imageColor,
  });
  final List<String> images;
  final int initialIndex;
  final int imageColor;

  @override
  State<ZoomGallery> createState() => _ZoomGalleryState();
}

class _ZoomGalleryState extends State<ZoomGallery> {
  late final PageController _controller;
  final FocusNode _shortcutFocus = FocusNode();
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    _shortcutFocus.dispose();
    super.dispose();
  }

  /// Same resolution rules as the detail pipeline:
  /// empty → fallback icon, http(s) → cached network, else local asset.
  ImageProvider? _providerFor(String source) {
    if (source.isEmpty) return null;
    // Bounded decode like the detail path: fullscreen contain never
    // needs more than ~1080px per axis.
    if (source.startsWith('http')) {
      return CachedNetworkImageProvider(source,
          maxWidth: 1080, maxHeight: 1080);
    }
    return ResizeImage(AssetImage(source), width: 1080, height: 1080);
  }

  Widget _fallback() => Icon(
        Icons.texture,
        color: AppColors.white.withValues(alpha: .5),
        size: 120,
      );

  PhotoViewGalleryPageOptions _pageOption(String source) {
    // Empty source: zoomable placeholder, no image decode at all.
    if (source.isEmpty) {
      return PhotoViewGalleryPageOptions.customChild(
        childSize: const Size(120, 120),
        minScale: 1.0,
        maxScale: 4.0,
        child: _fallback(),
      );
    }
    return PhotoViewGalleryPageOptions(
      imageProvider: _providerFor(source),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4.0,
      errorBuilder: (_, __, ___) => Center(child: _fallback()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // TalkBack/VoiceOver announce this as a dialog; Escape or the back
    // affordance closes it (system back pops the pushed route natively).
    return Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.galleryViewerLabel,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Focus(
          focusNode: _shortcutFocus,
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColors.black,
            appBar: AppBar(
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
              automaticallyImplyLeading: false,
              title: Text('${_current + 1} / ${widget.images.length}'),
              actions: [
                IconButton(
                  tooltip: l10n.galleryClose,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            body: Stack(
              children: [
                PhotoViewGallery.builder(
                  itemCount: widget.images.length,
                  pageController: _controller,
                  onPageChanged: (i) => setState(() => _current = i),
                  backgroundDecoration:
                      const BoxDecoration(color: AppColors.black),
                  loadingBuilder: (_, __) => Center(child: _fallback()),
                  builder: (_, index) => _pageOption(widget.images[index]),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Center(
                    child: Text(
                      widget.images.length > 1
                          ? '${l10n.galleryZoomHint} · ${l10n.gallerySwipeHint}'
                          : l10n.galleryZoomHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
