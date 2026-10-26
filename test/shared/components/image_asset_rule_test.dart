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

  test('assets/brand contains only the approved brand PNGs', () {
    final root = Directory('assets/brand');
    expect(root.existsSync(), isTrue);

    final files = root.listSync(recursive: true).whereType<File>().toList();
    final nonPng = files
        .where((file) => _extension(file.path).toLowerCase() != '.png')
        .map((file) => file.path)
        .toList();
    expect(nonPng, isEmpty,
        reason: 'assets/brand holds PNG brand assets only: $nonPng');

    final names = files.map((file) => file.uri.pathSegments.last).toSet();
    expect(names, {
      'logo.png',
      'logo_transparent.png',
      'logo_lockup_on_dark.png',
      'logo_lockup_on_light.png',
      'logo_mark_on_dark.png',
      'logo_mark_on_light.png',
    });
  });
}

String _extension(String path) {
  final separator = path.lastIndexOf('.');
  return separator == -1 ? '' : path.substring(separator);
}
