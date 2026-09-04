import 'package:al_batal_elite/features/support/data/local_support_repository.dart';
import 'package:al_batal_elite/features/support/domain/entities/support_channel.dart';
import 'package:al_batal_elite/features/support/presentation/pages/support_pages.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the owner-verified support contacts: no fake numbers or
/// RFC-2606 placeholder domains may ever ship again (live-found
/// 2026-09-04: wa.me/1234567890 + albatal-store.example).
void main() {
  group('LocalSupportRepository contacts', () {
    test('WhatsApp channel uses the verified business number', () {
      final channels = const LocalSupportRepository().getChannels();
      final whatsapp = channels.firstWhere(
        (c) => c.kind == SupportChannelKind.whatsapp,
      );
      expect(whatsapp.value, 'https://wa.me/201154580512');
    });

    test('email channel uses the verified support address', () {
      final channels = const LocalSupportRepository().getChannels();
      final email = channels
          .firstWhere((c) => c.kind == SupportChannelKind.email);
      expect(email.value, 'al3tar66@gmail.com');
    });

    test('no placeholder contacts', () {
      final values = const LocalSupportRepository()
          .getChannels()
          .map((c) => c.value ?? '')
          .join(' ');
      for (final banned in [
        '1234567890',
        '201000000000',
        '.example',
        '000000',
      ]) {
        expect(values.contains(banned), isFalse, reason: 'banned: $banned');
      }
    });
  });

  group('SupportPage', () {
    testWidgets('renders repository channels, never hardcoded contacts',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SupportPage(
            supportRepository: LocalSupportRepository()),
      ));
      await tester.pumpAndSettle();

      // Real email channel from the repository is visible (the launch
      // target itself is pinned by the unit tests above)…
      expect(find.text('al3tar66@gmail.com'), findsOneWidget);
      // …and no fake contact string is rendered anywhere.
      expect(find.textContaining('1234567890'), findsNothing);
      expect(find.textContaining('.example'), findsNothing);
    });
  });
}
