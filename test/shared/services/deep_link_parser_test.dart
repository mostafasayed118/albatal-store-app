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

    test('parses password-recovery links (custom scheme and web)', () {
      expect(
        parseDeepLink(Uri.parse('albatal://reset-password'), webBase: _base()),
        const ResetPasswordDeepLink(),
      );
      expect(
        parseDeepLink(
          Uri.parse('https://albatal.app/reset-password'
              '#access_token=x&type=recovery'),
          webBase: _base(),
        ),
        const ResetPasswordDeepLink(),
      );
    });

    test('parses oauth callbacks and preserves the full URI', () {
      final custom = parseDeepLink(
        Uri.parse('albatal://login-callback?code=abc&state=xyz'),
        webBase: _base(),
      );
      expect(custom, isA<OAuthCallbackDeepLink>());
      expect(
        (custom as OAuthCallbackDeepLink).uri.toString(),
        'albatal://login-callback?code=abc&state=xyz',
      );

      final web = parseDeepLink(
        Uri.parse('https://albatal.app/login-callback?code=abc#state=xyz'),
        webBase: _base(),
      );
      expect(web, isA<OAuthCallbackDeepLink>());
      expect((web as OAuthCallbackDeepLink).uri.queryParameters['code'], 'abc');
      expect(web.uri.fragment, 'state=xyz');
    });

    test('keeps an OAuth error callback for graceful handling', () {
      final link = parseDeepLink(
        Uri.parse(
          'albatal://login-callback/?error=server_error'
          '&error_code=unexpected_failure'
          '&error_description=Unable+to+exchange+external+code',
        ),
        webBase: _base(),
      );
      expect(link, isA<OAuthCallbackDeepLink>());
      expect(
        (link as OAuthCallbackDeepLink).uri.queryParameters['error'],
        'server_error',
      );
      expect(link.uri.queryParameters['error_code'], 'unexpected_failure');
    });

    test('rejects foreign-host and deeper-path oauth callbacks', () {
      expect(
        parseDeepLink(
          Uri.parse('https://evil.example/login-callback?code=abc'),
          webBase: _base(),
        ),
        isNull,
      );
      expect(
        parseDeepLink(
          Uri.parse('albatal://login-callback/extra?code=abc'),
          webBase: _base(),
        ),
        isNull,
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
      expect(
        parseDeepLink(
          Uri.parse('https://evil.example/reset-password'),
          webBase: _base(),
        ),
        isNull,
      );
    });

    test('rejects plain http:// web links even on the configured host', () {
      expect(
        parseDeepLink(
          Uri.parse('http://albatal.app/product/fabric-42'),
          webBase: _base(),
        ),
        isNull,
      );
      expect(
        parseDeepLink(
          Uri.parse('http://albatal.app/catalog?q=silk'),
          webBase: _base(),
        ),
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

    test('rejects encoded path separators in product ids (R12)', () {
      expect(
        parseDeepLink(
          Uri.parse('https://albatal.app/product/a%2Fb'),
          webBase: _base(),
        ),
        isNull,
      );
      expect(
        parseDeepLink(
          Uri.parse('albatal://product/a%2Fb'),
          webBase: _base(),
        ),
        isNull,
      );
    });
  });
}
