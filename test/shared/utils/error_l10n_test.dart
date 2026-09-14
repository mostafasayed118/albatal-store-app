import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/utils/error_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the error-code → localized-copy helper (audit
/// 2026-09-14). Same shape as payment_error_mapper_test.dart:
/// [localizedErrorText] is pure so it loads the delegate directly;
/// [localizedErrorMessage] runs under a harness that mounts the l10n
/// delegates so [AppLocalizations.of] resolves.
void main() {
  late AppLocalizations en;
  late AppLocalizations ar;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  group('localizedErrorText (pure)', () {
    test('known codes map to localized copy', () {
      expect(localizedErrorText(en, 'auth_invalid_credentials', 'RAW'),
          'Invalid email or password');
      expect(localizedErrorText(en, 'checkout_failed', 'RAW'),
          'Checkout failed. Please try again.');
      expect(localizedErrorText(en, 'network_error', 'RAW'),
          'Payment failed. Please try again.');
      expect(localizedErrorText(en, 'oauth_cancelled', 'RAW'),
          'Sign-in was cancelled.');
      expect(localizedErrorText(en, 'delete_email_mismatch', 'RAW'),
          'The email does not match this account');
    });

    test('unknown or null code falls back to the original message', () {
      // Unknown codes pass server-authored messages verbatim (P1 ruling).
      expect(localizedErrorText(en, 'no_such_code', 'RAW'), 'RAW');
      expect(localizedErrorText(en, null, 'RAW'), 'RAW');
    });

    test('Arabic locale yields proper Arabic copy', () {
      final localized = localizedErrorText(ar, 'auth_invalid_credentials',
          'RAW');
      expect(localized, isNot('RAW'));
      expect(localized,
          isNot(localizedErrorText(en, 'auth_invalid_credentials', 'RAW')));
      // Arabic copy must not be an English string (tone guard).
      expect(localized, contains(RegExp(r'[\u0600-\u06FF]')));
    });
  });

  group('localizedErrorMessage (context)', () {
    Widget harness({required ValueChanged<BuildContext> onBuild}) =>
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              onBuild(context);
              return const SizedBox.shrink();
            },
          ),
        );

    testWidgets('mapped code localizes; unknown/missing falls back',
        (tester) async {
      late String mapped;
      late String unknown;
      late String missing;
      await tester.pumpWidget(harness(onBuild: (context) {
        mapped = localizedErrorMessage(
              context,
              'Invalid email or password',
              code: 'auth_invalid_credentials',
            ) ??
            '';
        unknown = localizedErrorMessage(
              context,
              'Server said something odd',
              code: 'weird_code',
            ) ??
            '';
        missing = localizedErrorMessage(
              context,
              'Failed to read session',
            ) ??
            '';
      }));
      expect(mapped, 'Invalid email or password');
      expect(unknown, 'Server said something odd');
      expect(missing, 'Failed to read session');
    });

    testWidgets('bare code-as-message localizes (payment cubit shape)',
        (tester) async {
      late String resolved;
      await tester.pumpWidget(harness(onBuild: (context) {
        resolved = localizedErrorMessage(context, 'network_error') ?? '';
      }));
      expect(resolved, 'Payment failed. Please try again.');
    });

    testWidgets('null message stays null', (tester) async {
      late String? resolved;
      await tester.pumpWidget(harness(onBuild: (context) {
        resolved = localizedErrorMessage(context, null);
      }));
      expect(resolved, isNull);
    });
  });
}
