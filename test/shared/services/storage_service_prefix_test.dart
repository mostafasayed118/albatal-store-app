import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uploadProductImage rejects path outside product prefix', () async {
    final svc = StorageService(client: null);
    expect(
      () => svc.buildProductImagePath('prod-123', '../../etc/passwd'),
      throwsA(isA<ArgumentError>()),
    );
  });
  test('buildProductImagePath returns correct prefix', () {
    final svc = StorageService(client: null);
    final path = svc.buildProductImagePath('abc-uuid', 'photo.jpg');
    expect(path, startsWith('product-images/abc-uuid/'));
  });
}
