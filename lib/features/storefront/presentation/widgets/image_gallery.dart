import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import 'product_image_resolver.dart';
import 'zoom_gallery.dart';

/// Horizontal page-view gallery with dot indicators.
class ImageGallery extends StatefulWidget {
  const ImageGallery({super.key, required this.product});
  final Product product;

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  int _current = 0;
  late List<String> _allImages;

  @override
  void initState() {
    super.initState();
    _allImages = _resolveImages(widget.product);
  }

  @override
  void didUpdateWidget(covariant ImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The gallery outlived its product (same route, new product — e.g.
    // a related-tap that reuses the widget): rebuild the image list and
    // reset the page instead of showing the previous product's photos.
    if (oldWidget.product != widget.product) {
      _allImages = _resolveImages(widget.product);
      _current = 0;
    }
  }

  static List<String> _resolveImages(Product product) {
    final images = [
      if (product.imageAsset != null) product.imageAsset!,
      ...product.images.where((i) => i != product.imageAsset),
    ];
    if (images.isEmpty) images.add('');
    return images;
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
              // that a bare asset render would crash on.
              child: ProductImageResolver(
                imageColor: widget.product.imageColor,
                asset: _allImages[i].isEmpty ? null : _allImages[i],
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
