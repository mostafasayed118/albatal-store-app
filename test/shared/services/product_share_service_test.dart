import 'package:al_batal_elite/shared/services/product_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('productUrl (§5)', () {
    test('builds canonical product links from the env base url', () {
      expect(productUrl('fabric-42'), 'https://albatal.app/product/fabric-42');
    });
  });
}
