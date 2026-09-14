import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // A standalone client (no Supabase.initialize) is enough for URL
  // building; the service never touches the network in these tests.
  final svc = StorageService(
    client: SupabaseClient('https://test.supabase.co', 'test-anon-key'),
  );
  const bucket = 'product-images';

  test('uploadProductImage rejects path outside product prefix', () async {
    final svc = StorageService();
    expect(
      () => svc.buildProductImagePath('prod-123', '../../etc/passwd'),
      throwsA(isA<ArgumentError>()),
    );
  });
  test('buildProductImagePath returns correct prefix', () {
    final svc = StorageService();
    final path = svc.buildProductImagePath('abc-uuid', 'photo.jpg');
    expect(path, startsWith('product-images/abc-uuid/'));
  });

  group('getProductImageUrl transform', () {
    test('with width returns transform-aware render URL', () {
      final url = svc.getProductImageUrl('p/1/a.jpg', width: 420);
      expect(url, contains('/render/image/public/$bucket/'));
      expect(url, contains('width=420'));
      expect(url, contains('resize=contain'));
      expect(url, contains('quality=80'));
    });
    test('without width returns the untransformed public URL', () {
      final url = svc.getProductImageUrl('p/1/a.jpg');
      expect(url, contains('/object/public/$bucket/'));
      expect(url, isNot(contains('width=')));
      expect(url, isNot(contains('/render/image/')));
    });
  });

  group('transformPublicUrl', () {
    test('upgrades a product-images public URL to the render variant', () {
      const publicUrl =
          'https://test.supabase.co/storage/v1/object/public/product-images/p/1/a.jpg';
      final url = StorageService.transformPublicUrl(publicUrl, width: 180);
      expect(
        url,
        'https://test.supabase.co/storage/v1/render/image/public/'
        'product-images/p/1/a.jpg?width=180&resize=contain&quality=80',
      );
    });
    test('leaves non-product-images URLs untouched', () {
      const other =
          'https://test.supabase.co/storage/v1/object/public/avatars/u/avatar.png';
      expect(
        StorageService.transformPublicUrl(other, width: 180),
        other,
      );
      const asset = 'assets/images/x.svg';
      expect(StorageService.transformPublicUrl(asset, width: 180), asset);
    });
  });

  group('uploadProductImage service-layer guards', () {
    test('rejects a disallowed extension', () async {
      expect(
        () => svc.uploadProductImage(
            'p1', const [1, 2, 3], 'photo.gif', 'image/gif'),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('rejects a file name without an extension', () async {
      expect(
        () => svc.uploadProductImage('p1', const [1, 2, 3], 'photo', 'image/jpeg'),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('rejects bytes over the 5 MB ceiling', () async {
      final oversized = List<int>.filled(
        StorageService.productImageMaxBytes + 1,
        0,
      );
      expect(
        () => svc.uploadProductImage('p1', oversized, 'photo.jpg', 'image/jpeg'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
