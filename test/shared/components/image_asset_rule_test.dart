import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assets/images contains SVG files only', () {
    final root = Directory('assets/images');
    expect(root.existsSync(), isTrue);

    final rasterExtensions = {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
      '.avif'
    };
    final rasterFiles = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) =>
            rasterExtensions.contains(_extension(file.path).toLowerCase()))
        .map((file) => file.path)
        .toList();

    expect(rasterFiles, isEmpty,
        reason: 'Runtime app-owned image assets must be SVG: $rasterFiles');
  });

  test('SVG asset paths have SVG extensions', () {
    final root = Directory('assets/images');
    final nonSvgFiles = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => _extension(file.path).toLowerCase() != '.svg')
        .map((file) => file.path)
        .toList();

    expect(nonSvgFiles, isEmpty,
        reason: 'Unexpected non-SVG runtime asset: $nonSvgFiles');
  });
}

String _extension(String path) {
  final separator = path.lastIndexOf('.');
  return separator == -1 ? '' : path.substring(separator);
}
