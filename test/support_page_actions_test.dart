import 'package:al_batal_elite/features/support/domain/entities/support_channel.dart';
import 'package:al_batal_elite/features/support/domain/repositories/support_repository.dart';
import 'package:al_batal_elite/features/support/presentation/pages/support_pages.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Fake repository so the test controls exactly which channels render and
/// does not depend on the GetIt service locator.
class _FakeSupportRepository implements SupportRepository {
  @override
  List<SupportChannel> getChannels() => const [
        SupportChannel(
          id: 'whatsapp',
          label: 'WhatsApp',
          kind: SupportChannelKind.whatsapp,
          value: 'https://wa.me/201000000000',
        ),
        SupportChannel(
          id: 'email',
          label: 'Email',
          kind: SupportChannelKind.email,
          value: 'support@albatal-store.example',
        ),
        SupportChannel(
          id: 'faq',
          label: 'FAQ',
          kind: SupportChannelKind.faq,
        ),
      ];
}

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/support',
    routes: [
      GoRoute(
        path: '/support',
        builder: (_, __) => SupportPage(repository: _FakeSupportRepository()),
      ),
      GoRoute(path: '/faq', builder: (_, __) => const FaqPage()),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupportPage actions', () {
    // Capture Clipboard.setData platform calls so we can prove the copy
    // action really writes to the clipboard (not a no-op onTap).
    final clipboardCalls = <MethodCall>[];
    setUp(() {
      clipboardCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls.add(call);
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders one tile per repository channel', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // 2 copy tiles (whatsapp, email) + 1 chevron (faq).
      expect(find.byIcon(Icons.copy), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('WhatsApp tile copies its value and confirms via snackbar',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chat));
      await tester.pump(); // let the snackbar appear

      expect(clipboardCalls, hasLength(1));
      expect(
        clipboardCalls.single.arguments['text'],
        'https://wa.me/201000000000',
      );
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Email tile copies its value to the clipboard', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.email));
      await tester.pump();

      expect(clipboardCalls, hasLength(1));
      expect(
        clipboardCalls.single.arguments['text'],
        'support@albatal-store.example',
      );
    });

    testWidgets('FAQ tile navigates to the FaqPage', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.byType(FaqPage), findsOneWidget);
      // FAQ content is rendered from l10n as expandable entries.
      expect(find.byType(ExpansionTile), findsWidgets);
      // Copy tiles from the support page are gone after navigation.
      expect(find.byIcon(Icons.copy), findsNothing);
    });
  });
}
