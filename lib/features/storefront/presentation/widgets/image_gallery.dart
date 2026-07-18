import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import 'product_image_placeholder.dart';

/// Horizontal page-view gallery with dot indicators and zoom.
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
        builder: (_) => _ZoomGallery(
          images: _allImages,
          initialIndex: initialIndex,
          imageColor: widget.product.imageColor,
        ),
      ),
    );
  }
}

class _ZoomGallery extends StatefulWidget {
  const _ZoomGallery({
    required this.images,
    required this.initialIndex,
    required this.imageColor,
  });
  final List<String> images;
  final int initialIndex;
  final int imageColor;

  @override
  State<_ZoomGallery> createState() => _ZoomGalleryState();
}

class _ZoomGalleryState extends State<_ZoomGallery> {
  late final PageController _controller;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: widget.images[i].isEmpty
                ? Icon(Icons.texture,
                    color: Colors.white.withValues(alpha: .5), size: 120)
                : Image.asset(widget.images[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
