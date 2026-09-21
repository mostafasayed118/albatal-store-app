import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import 'product_image_resolver.dart';
import 'zoom_gallery.dart';

/// Horizontal page-view gallery with dot indicators.
class ImageGallery extends StatefulWidget {
  const ImageGallery({super.key, required this.product});
  final Product product;

  /// The gallery's resolved image list: the primary (when the list does not
  /// already carry the same photo) followed by [Product.images].
  ///
  /// Public only so the width-dedupe pins can exercise it without rendering
  /// network images in a widget test; not part of the widget's API.
  @visibleForTesting
  static List<String> resolveImages(Product product) {
    // The primary is kept only when the gallery list does not already carry
    // the SAME photo. A remote primary arrives at the card budget
    // (`StorageService.gridImageWidth`, 420) while the gallery render is the
    // detail width (720), so equality on the URL would read one photo as two
    // and duplicate the first slide — compare the object the URL points at
    // (everything before the render query) instead.
    final primary = product.imageAsset;
    final alreadyListed = primary != null &&
        product.images.any(
          (i) => _imageObject(i) == _imageObject(primary),
        );
    final images = [
      if (primary != null && !alreadyListed) primary,
      ...product.images,
    ];
    if (images.isEmpty) images.add('');
    return images;
  }

  /// The stored object a public/render URL points at, ignoring the width the
  /// requesting surface asked for: `…/a.jpg?width=420` and `…/a.jpg?width=720`
  /// are the same photo. Local asset paths carry no query and pass through.
  static String _imageObject(String url) {
    final query = url.indexOf('?');
    return query < 0 ? url : url.substring(0, query);
  }

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  int _current = 0;
  late List<String> _allImages;

  @override
  void initState() {
    super.initState();
    _allImages = ImageGallery.resolveImages(widget.product);
  }

  @override
  void didUpdateWidget(covariant ImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The gallery outlived its product (same route, new product — e.g.
    // a related-tap that reuses the widget): rebuild the image list and
    // reset the page instead of showing the previous product's photos.
    if (oldWidget.product != widget.product) {
      _allImages = ImageGallery.resolveImages(widget.product);
      _current = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: _allImages.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _showZoomed(context, i),
              // Shared resolver: handles http URLs and load failures
              // that a bare asset render would crash on. Decode budget
              // (audit P4): the gallery renders at detail width, so pin
              // the 720px detail budget instead of the 1080px default.
              child: ProductImageResolver(
                imageColor: widget.product.imageColor,
                asset: _allImages[i].isEmpty ? null : _allImages[i],
                cacheWidth: 720,
              ),
            ),
          ),
        ),
        if (_allImages.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _allImages.length,
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _current
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showZoomed(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZoomGallery(
          images: _allImages,
          initialIndex: initialIndex,
          imageColor: widget.product.imageColor,
        ),
      ),
    );
  }
}
