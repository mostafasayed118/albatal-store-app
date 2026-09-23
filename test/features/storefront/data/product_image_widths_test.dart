import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit 2026-09-14 P0-4: product images must be requested as width-bounded
/// RENDER URLs, never the full upload.
///
/// Audit 2026-09-21 (dual cache keys): `imageAsset` and `images` resolve
/// at the SAME [StorageService.detailImageWidth] — one photo produces one
/// URL string and therefore exactly one `CachedNetworkImage` cache entry.
/// Surfaces bound their own DECODE (grid cards pass `cacheWidth: 420`),
/// so both halves stay pinned: a fix that re-split the budgets (or
/// dropped the bound on one surface) would fail here.
final class _WidthRecordingStorage extends StorageService {
  /// Master's constructor requires the client explicitly (no global fallback),
  /// and these doubles exist to exercise the pure URL builders — which never
  /// touch it — so they pass `null`.
  _WidthRecordingStorage() : super(client: null);

  /// Every (path, width) the mapper asked for, in call order, as
  /// `'<path>@<width>'` so a swapped budget cannot hide.
  final requested = <String>[];

  @override
  String getProductImageUrl(String storagePath) => '/public/$storagePath';

  @override
  String getProductImageUrlForWidth(String storagePath, int width) {
    requested.add('$storagePath@$width');
    return '/render/$storagePath?width=$width';
  }
}

/// Overrides ONLY the bare public URL, so the REAL width helper runs — the
/// fail-open path (extension gate + base derivation) is exercised, not stubbed.
final class _BareStorage extends StorageService {
  _BareStorage() : super(client: null);

  @override
  String getProductImageUrl(String storagePath) => 'cdn:$storagePath';
}

Map<String, dynamic> _row(List<Map<String, dynamic>> images) => {
      'id': 'p1',
      'name': 'Thobe',
      'base_price': 10000,
      'product_images': images,
    };

void main() {
  group('ProductCodec.fromRow — render-URL widths (P0-4)', () {
    test('images lands at the detail budget, in sort_order', () {
      final storage = _WidthRecordingStorage();
      final product = ProductCodec.fromRow(
        _row([
          {'storage_path': 'a.jpg', 'sort_order': 1},
          {'storage_path': 'b.jpg', 'sort_order': 0},
        ]),
        const [],
        storageService: storage,
      )!;

      expect(product.images, [
        '/render/b.jpg?width=${StorageService.detailImageWidth}',
        '/render/a.jpg?width=${StorageService.detailImageWidth}',
      ]);
    });

    test('imageAsset is the PRIMARY image at the detail budget', () {
      final storage = _WidthRecordingStorage();
      final product = ProductCodec.fromRow(
        _row([
          {'storage_path': 'a.jpg', 'sort_order': 1},
          {'storage_path': 'b.jpg', 'sort_order': 0},
        ]),
        const [],
        storageService: storage,
      )!;

      // b.jpg sorts first, so the grid must show b — not the row's first entry.
      expect(
        product.imageAsset,
        '/render/b.jpg?width=${StorageService.detailImageWidth}',
      );

      // One budget everywhere: gallery entries AND the primary resolve at
      // detail, so the primary URL string is byte-identical to the gallery's
      // copy of the same photo — ONE cache entry per photo (audit 2026-09-21).
      expect(storage.requested, [
        'b.jpg@${StorageService.detailImageWidth}',
        'a.jpg@${StorageService.detailImageWidth}',
        'b.jpg@${StorageService.detailImageWidth}',
      ]);
      expect(product.imageAsset, product.images.first);
    });

    test(
        'a non-renderable path falls back to the bare public URL on both '
        'surfaces', () {
      final product = ProductCodec.fromRow(
        _row([
          {'storage_path': 'logo.svg', 'sort_order': 0},
        ]),
        const [],
        storageService: _BareStorage(),
      )!;

      // `.svg` is outside the render allowlist, so the real helper returns the
      // public URL instead of a render URL — the image still renders.
      expect(product.images, ['cdn:logo.svg']);
      expect(product.imageAsset, 'cdn:logo.svg');
    });

    test('no usable image leaves both surfaces empty', () {
      final storage = _WidthRecordingStorage();
      final product = ProductCodec.fromRow(
        _row([
          {'storage_path': 42, 'sort_order': 0},
          {'storage_path': '', 'sort_order': 1},
        ]),
        const [],
        storageService: storage,
      )!;

      expect(product.images, isEmpty);
      expect(product.imageAsset, isNull,
          reason: 'cards must fall back to the swatch, not to a broken URL');
      expect(storage.requested, isEmpty,
          reason: 'no image means no URL building at all');
    });

    test('both surfaces survive a cache round trip', () {
      final product = ProductCodec.fromRow(
        _row([
          {'storage_path': 'a.jpg', 'sort_order': 0},
          {'storage_path': 'b.jpg', 'sort_order': 1},
        ]),
        const [],
        storageService: _WidthRecordingStorage(),
      )!;

      final restored = ProductCodec.decode(ProductCodec.encode(product))!;
      expect(restored.imageAsset, product.imageAsset);
      expect(restored.images, product.images);
    });
  });
}
