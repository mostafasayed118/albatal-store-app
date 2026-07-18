import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import 'product_image_placeholder.dart';
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
  late final List<String> _allImages;

  @override
  void initState() {
    super.initState();
    _allImages = [
      if (widget.product.imageAsset != null) widget.product.imageAsset!,
      ...widget.product.images.where((i) => i != widget.product.imageAsset),
    ];
    if (_allImages.isEmpty) _allImages.add('');
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
              child: ProductImagePlaceholder(
                imageColor: widget.product.imageColor,
                imageAsset: _allImages[i].isEmpty ? null : _allImages[i],
                constraints: const BoxConstraints.expand(height: 300),
                size: 80,
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
