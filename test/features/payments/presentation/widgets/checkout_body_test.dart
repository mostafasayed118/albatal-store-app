import 'dart:async';

import 'package:al_batal_elite/features/payments/presentation/widgets/checkout_body.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

const _safeUrl =
    'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=abc';

class _FakePlatformController extends PlatformWebViewController {
  _FakePlatformController(super.params) : super.implementation();

  JavaScriptMode? javaScriptMode;
  PlatformNavigationDelegate? navigationDelegate;
  LoadRequestParams? loaded;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    javaScriptMode = mode;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate delegate) async {
    navigationDelegate = delegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loaded = params;
  }
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? navigationRequest;
  PageEventCallback? pageStarted;
  PageEventCallback? pageFinished;
  UrlChangeCallback? urlChange;

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback callback) async {
    navigationRequest = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    pageStarted = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    pageFinished = callback;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback callback) async {
    urlChange = callback;
  }
}

class _FakePlatformWidget extends PlatformWebViewWidget {
  _FakePlatformWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FakeWebViewPlatform extends WebViewPlatform {
  late _FakePlatformController controller;
  late _FakeNavigationDelegate navigationDelegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    controller = _FakePlatformController(params);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
      PlatformNavigationDelegateCreationParams params) {
    navigationDelegate = _FakeNavigationDelegate(params);
    return navigationDelegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams params) =>
      _FakePlatformWidget(params);
}

Widget _harness(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

GoRouter _router() {
  final router = GoRouter(
    initialLocation: '/checkout',
    routes: [
      GoRoute(
        path: '/checkout',
        builder: (_, __) => const CheckoutBody(checkoutUrl: _safeUrl),
      ),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

void main() {
  testWidgets(
      'without a WebView platform the body renders the safe placeholder',
      (tester) async {
    // First test in the file: WebViewPlatform.instance is still null, which
    // is exactly the widget-test environment CheckoutBody defends against.
    await tester.pumpWidget(_harness(_router()));
    await tester.pump();

    expect(find.byType(WebViewWidget), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(CheckoutBody), findsOneWidget);
  });

  group('with a WebView platform', () {
    late _FakeWebViewPlatform platform;

    setUp(() {
      platform = _FakeWebViewPlatform();
      WebViewPlatform.instance = platform;
    });

    testWidgets('configures the controller and hides the loader when loaded',
        (tester) async {
      await tester.pumpWidget(_harness(_router()));
      await tester.pump();

      expect(platform.controller.javaScriptMode, JavaScriptMode.unrestricted);
      expect(platform.controller.loaded?.uri, Uri.parse(_safeUrl));
      expect(platform.controller.navigationDelegate, isNotNull);
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      platform.navigationDelegate.pageStarted!(_safeUrl);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      platform.navigationDelegate.pageFinished!(_safeUrl);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('navigation and URL-change callbacks enforce the allowlist',
        (tester) async {
      await tester.pumpWidget(_harness(_router()));
      await tester.pump();

      final safeDecision = await platform.navigationDelegate.navigationRequest!(
        const NavigationRequest(url: _safeUrl, isMainFrame: true),
      );
      expect(safeDecision, NavigationDecision.navigate);

      final unsafeDecision =
          await platform.navigationDelegate.navigationRequest!(
        const NavigationRequest(
          url: 'https://evil.example.com/checkout',
          isMainFrame: true,
        ),
      );
      expect(unsafeDecision, NavigationDecision.prevent);

      // Null URL and safe URL changes are ignored; an off-allowlist URL is
      // logged (token-redacted) without throwing.
      platform.navigationDelegate.urlChange!(const UrlChange(url: null));
      platform.navigationDelegate.urlChange!(const UrlChange(url: _safeUrl));
      platform.navigationDelegate.urlChange!(
        const UrlChange(url: 'http://evil.example.com/?payment_token=SECRET'),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the close button pops the checkout route', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/checkout',
            builder: (_, __) => const CheckoutBody(checkoutUrl: _safeUrl),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_harness(router));
      unawaited(router.push('/checkout'));
      // The loading spinner animates forever, so pump fixed frames instead
      // of pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CheckoutBody), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
