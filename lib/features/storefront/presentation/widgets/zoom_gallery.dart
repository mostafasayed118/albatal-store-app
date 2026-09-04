import 'package:flutter/material.dart';

import '../../../../shared/components/app_image.dart';
import '../../../../shared/theme/app_colors.dart';

/// Full-screen zoom gallery with page view and interactive viewer.
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
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
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
                    color: AppColors.white.withValues(alpha: .5), size: 120)
                : AppImage(
                    source: widget.images[i],
                    fit: BoxFit.contain,
                    placeholder: Icon(Icons.texture,
                        color: AppColors.white.withValues(alpha: .5),
                        size: 120),
                  ),
          ),
        ),
      ),
    );
  }
}
