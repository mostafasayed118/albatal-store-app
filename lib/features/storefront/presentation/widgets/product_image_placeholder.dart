import 'package:flutter/material.dart';

class ProductImagePlaceholder extends StatelessWidget {
  const ProductImagePlaceholder({
    super.key,
    required this.imageColor,
    this.size = 42,
    this.constraints,
  });

  final int imageColor;
  final double size;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      constraints: constraints,
      decoration: BoxDecoration(
        color: Color(imageColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          Center(child: Icon(Icons.texture, color: Colors.white, size: size)),
    );
    return constraints != null ? container : Expanded(child: container);
  }
}
