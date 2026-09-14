import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:al_batal_elite/shared/services/whatsapp_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/local_catalog_repository.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

/// Recording [ExternalLinkLauncher] fake — the same interface-wrapping
/// seam as DeepLinkService/PushService, so url_launcher is never mocked
/// through its platform channel.
class _RecordingLauncher implements ExternalLinkLauncher {
  _RecordingLauncher({this.ok = true});

  final bool ok;
  final List<Uri> launched = [];

  @override
  Future<bool> launchExternal(Uri uri) async {
    launched.add(uri);
    return ok;
  }
}

Widget _harness(String productId, _RecordingLauncher launcher) {
  final persistence = MemoryStorefrontPersistence();
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WishlistCubit(persistence)),
        BlocProvider(create: (_) => CartCubit(persistence)),
      ],
      child: DetailsPage(
        id: productId,
        catalogRepository: LocalCatalogRepository(),
        whatsappShareService: WaMeWhatsAppShareService(launcher),
      ),
    ),
  );
}

void main() {
  group('whatsappShareUrl (#13)', () {
    const message =
        'Royal Emerald Silk — 1290 EGY\nhttps://albatal.app/product/silk-01';

    test('builds a wa.me universal link with the text prefill', () {
      final uri = whatsappShareUrl(message);
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], message);
    });

    test('percent-encodes spaces as %20 — never + (wa.me renders + literally)',
        () {
      final uri = whatsappShareUrl(message);
      final s = uri.toString();
      expect(s.contains(' '), isFalse, reason: 'no raw spaces in a URL');
      expect(s.contains('+'), isFalse, reason: '+ decodes to a space on wa.me');
      expect(s, contains('%20'));
    });

    test('is RTL-safe: Arabic text round-trips through the encoding', () {
      const ar = 'حرير ملكي بسعر 1290 EGY\nhttps://albatal.app/product/silk-01';
      final uri = whatsappShareUrl(ar);
      // The wire format is ASCII-only (valid UTF-8 percent escapes), and
      // decoding restores the Arabic message byte-for-byte.
      expect(uri.toString().codeUnits.every((c) => c < 128), isTrue);
      expect(uri.queryParameters['text'], ar);
    });

    test('localized prefill carries name, price and deep link (EN + AR)', () {
      const url = 'https://albatal.app/product/silk-01';
      final en = AppLocalizationsEn()
          .whatsappShareProductMessage('Royal Emerald Silk', '1290 EGY', url);
      expect(en, 'Royal Emerald Silk — 1290 EGY\n$url');
      expect(en.contains(url), isTrue);

      final ar = AppLocalizationsAr()
          .whatsappShareProductMessage('حرير ملكي', '1290 EGY', url);
      expect(ar, 'حرير ملكي بسعر 1290 EGY\n$url');
      // The Arabic template must be real Arabic, not a copy of the EN one.
      expect(ar, isNot(en));
      expect(ar, contains('بسعر'));
    });
  });

  group('details page WhatsApp share option (#13)', () {
    testWidgets('appears next to the generic share fallback', (tester) async {
      final launcher = _RecordingLauncher();
      await tester.pumpWidget(_harness('silk-01', launcher));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byTooltip('Share on WhatsApp'), findsOneWidget);
      // The existing generic share stays as the fallback.
      expect(find.byTooltip('Share product'), findsOneWidget);
    });

    testWidgets('tap hands the localized wa.me link to the injected launcher',
        (tester) async {
      final launcher = _RecordingLauncher();
      await tester.pumpWidget(_harness('silk-01', launcher));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Share on WhatsApp'));
      await tester.pump();

      expect(launcher.launched, hasLength(1));
      final uri = launcher.launched.single;
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'],
          'Royal Emerald Silk — 1290 EGY\nhttps://albatal.app/product/silk-01');
    });

    testWidgets('shows the shared floating error when no app takes the link',
        (tester) async {
      final launcher = _RecordingLauncher(ok: false);
      await tester.pumpWidget(_harness('silk-01', launcher));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Share on WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
          find.text("Couldn't open that. Please try again."), findsOneWidget);
      expect(launcher.launched, hasLength(1));
    });
  });
}
