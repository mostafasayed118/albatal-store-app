import 'package:al_batal_elite/features/support/domain/entities/support_channel.dart';
import 'package:al_batal_elite/features/support/domain/repositories/support_repository.dart';
import 'package:al_batal_elite/features/support/presentation/pages/privacy_policy_page.dart';
import 'package:al_batal_elite/features/support/presentation/pages/returns_policy_page.dart';
import 'package:al_batal_elite/features/support/presentation/pages/shipping_policy_page.dart';
import 'package:al_batal_elite/features/support/presentation/pages/support_page.dart';
import 'package:al_batal_elite/features/support/presentation/pages/terms_of_service_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Channels implements SupportRepository {
  const _Channels(this.channels);
  final List<SupportChannel> channels;

  @override
  List<SupportChannel> getChannels() => channels;
}

const _tampered = [
  SupportChannel(
    id: 'wa',
    label: 'WhatsApp',
    kind: SupportChannelKind.whatsapp,
    value: 'javascript:alert(1)',
  ),
  SupportChannel(
    id: 'mail',
    label: 'Email',
    kind: SupportChannelKind.email,
    value: 'support@albatal.test',
  ),
];

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async => false);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  testWidgets('policy pages render their localized content', (tester) async {
    for (final page in <Widget>[
      const PrivacyPolicyPage(),
      const TermsOfServicePage(),
      const ShippingPolicyPage(),
      const ReturnsPolicyPage(),
    ]) {
      await tester.pumpWidget(_app(page));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
    }
  });

  group('SupportPage channel taps', () {
    testWidgets('allowed links launch when an external app accepts them',
        (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, (call) async => true);
      const channels = [
        SupportChannel(
          id: 'wa',
          label: 'WhatsApp',
          kind: SupportChannelKind.whatsapp,
          value: 'https://wa.me/201154580512',
        ),
        SupportChannel(
          id: 'mail',
          label: 'Email',
          kind: SupportChannelKind.email,
          value: 'support@albatal.test',
        ),
      ];

      await tester.pumpWidget(
          _app(const SupportPage(supportRepository: _Channels(channels))));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chat));
      await tester.pumpAndSettle();
      await tester.tap(find.text('support@albatal.test'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't open that. Please try again."), findsNothing);
    });

    testWidgets('whatsapp link is rejected and email tap acknowledges failure',
        (tester) async {
      await tester.pumpWidget(
          _app(const SupportPage(supportRepository: _Channels(_tampered))));
      await tester.pumpAndSettle();

      // The WhatsApp row is present because it has a value, but the
      // javascript: target must never be handed to the OS.
      expect(find.byIcon(Icons.chat), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chat));
      await tester.pumpAndSettle();
      expect(
          find.text("Couldn't open that. Please try again."), findsOneWidget);

      await tester.tap(find.text('support@albatal.test'));
      await tester.pumpAndSettle();
      expect(
          find.text("Couldn't open that. Please try again."), findsOneWidget);

      await tester.tap(find.text('Frequently Asked Questions'));
      await tester.pumpAndSettle();
      expect(find.text('Coming Soon'), findsOneWidget);
    });
  });
}
