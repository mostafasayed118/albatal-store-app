import 'package:al_batal_elite/shared/services/deep_link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Uri _base() => Uri.parse('https://albatal.app');

void main() {
  group('parseDeepLink (§5)', () {
    test('parses https product links on the configured host', () {
      final link = parseDeepLink(
        Uri.parse('https://albatal.app/product/fabric-42'),
        webBase: _base(),
      );
      expect(link, const ProductDeepLink('fabric-42'));
    });

    test('parses custom-scheme product links (host form)', () {
      final link = parseDeepLink(
        Uri.parse('albatal://product/fabric-42'),
        webBase: _base(),
      );
      expect(link, const ProductDeepLink('fabric-42'));
    });

    test('parses custom-scheme product links (path form)', () {
      final link = parseDeepLink(
        Uri.parse('albatal:///product/fabric-42'),
        webBase: _base(),
      );
      expect(link, const ProductDeepLink('fabric-42'));
    });

    test('parses catalog links with and without a query', () {
      expect(
        parseDeepLink(Uri.parse('https://albatal.app/catalog'),
            webBase: _base()),
        const CatalogDeepLink(),
      );
      expect(
        parseDeepLink(
          Uri.parse('https://albatal.app/catalog?q=silk'),
          webBase: _base(),
        ),
        const CatalogDeepLink(query: 'silk'),
      );
      expect(
        parseDeepLink(Uri.parse('albatal://catalog?q=wool'), webBase: _base()),
        const CatalogDeepLink(query: 'wool'),
      );
    });

    test('blank q degrades to a plain catalog link', () {
      expect(
        parseDeepLink(
          Uri.parse('https://albatal.app/catalog?q='),
          webBase: _base(),
        ),
        const CatalogDeepLink(),
      );
    });

    test('rejects foreign hosts, unknown paths and empty ids', () {
      expect(
        parseDeepLink(
          Uri.parse('https://evil.example/product/fabric-42'),
          webBase: _base(),
        ),
        isNull,
      );
      expect(
        parseDeepLink(Uri.parse('https://albatal.app/unknown/x'),
            webBase: _base()),
        isNull,
      );
      expect(
        parseDeepLink(Uri.parse('https://albatal.app/product/'),
            webBase: _base()),
        isNull,
      );
      expect(
        parseDeepLink(Uri.parse('ftp://albatal.app/product/fabric-42'),
            webBase: _base()),
        isNull,
      );
    });

    test('accepts any host when webBase has an empty host', () {
      // Dev/test flexibility: parser still constrains the path shape.
      expect(
        parseDeepLink(
          Uri.parse('https://localhost:8080/product/fabric-42'),
          webBase: Uri.parse('https://'),
        ),
        const ProductDeepLink('fabric-42'),
      );
    });
  });
}
