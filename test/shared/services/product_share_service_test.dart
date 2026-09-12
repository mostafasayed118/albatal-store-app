import 'package:al_batal_elite/shared/services/product_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('productShareMessage (§5)', () {
    test('embeds name, brand line and url', () {
      final msg = productShareMessage(
        name: 'Silk Mantily',
        url: 'https://albatal.app/product/fabric-42',
      );
      expect(msg,
          'Silk Mantily — Al Batal Elite\nhttps://albatal.app/product/fabric-42');
    });
  });

  group('productUrl (§5)', () {
    test('builds canonical product links from the env base url', () {
      expect(productUrl('fabric-42'), 'https://albatal.app/product/fabric-42');
    });
  });
}
