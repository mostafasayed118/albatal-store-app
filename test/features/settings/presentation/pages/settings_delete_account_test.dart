import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/data/local_settings_repository.dart';
import 'package:al_batal_elite/features/settings/domain/account_deletion_port.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/pages/settings_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The account-deletion confirm dialog (UX-043) must open reliably from the
/// settings row. Regression coverage for the on-device first-frame freeze
/// report (blank screen at ~3fps, first tap seemingly swallowed): the guard
/// waits for the tapped row's frame to settle before pushing the dialog and
/// defers keyboard focus until the dialog's first frame is on screen.
///
/// After the cross-feature import fix (audit 2026-09) the page depends on
/// the domain [AccountDeletionPort] instead of Auth/Cart/Wishlist cubits,
/// so these tests drive it through a recording fake port.
void main() {
  late _FakeAccountDeletionPort accountDeletion;
  late SettingsCubit settingsCubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    accountDeletion = _FakeAccountDeletionPort();
    settingsCubit = SettingsCubit(LocalSettingsRepository(prefs));
    await settingsCubit.load();
  });

  tearDown(() async {
    await settingsCubit.close();
  });

  Widget harness() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: settingsCubit,
        // The fake reports an authenticated session (delete row visible).
        child: SettingsPage(accountDeletion: accountDeletion),
      ),
    );
  }

  testWidgets(
      'delete-account row opens the confirm dialog reliably and '
      'cancel returns to settings', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsOneWidget);

    // The destructive row sits at the bottom of the settings list; make
    // sure the tap lands (test viewport is shorter than a phone screen).
    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    // The dialog must be on screen (regression: it used to be starved on
    // the first attempt) with the full disclosure copy and actions.
    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.text('Delete permanently'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete account?'), findsNothing);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets(
      'confirm stays disabled until an email is typed, then deletes '
      'and confirms with a snackbar', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    final disabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );
    expect(disabledButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ux043@example.com');
    await tester.pumpAndSettle();

    final enabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );
    expect(enabledButton.onPressed, isNotNull);

    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(accountDeletion.deletedEmails, ['ux043@example.com']);
    expect(accountDeletion.guestDataCleared, isTrue);
    expect(find.text('Account deleted'), findsOneWidget);
  });

  testWidgets('coded deletion failure shows localized retry copy, not the code',
      (tester) async {
    accountDeletion.nextResult =
        const Failure(AppError(kDeleteFailed, code: kDeleteFailed));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ux043@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(
        find.text('Account deletion failed. Please try again.'), findsOneWidget,
        reason: 'kDeleteFailed must localize via failureText, not verbatim');
  });

  testWidgets('uncoded server prose passes through verbatim (P1 ruling)',
      (tester) async {
    accountDeletion.nextResult =
        const Failure(AppError('server says no (verbatim)'));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ux043@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('server says no (verbatim)'), findsOneWidget);
  });
}

/// Authenticated fake port that records every deleteAccount call.
final class _FakeAccountDeletionPort implements AccountDeletionPort {
  final deletedEmails = <String>[];
  bool guestDataCleared = false;

  /// Injected failure for the next call (defaults to success).
  Result<void> nextResult = const Success(null);

  @override
  bool get isAuthenticated => true;

  @override
  Future<Result<void>> deleteAccount({required String email}) async {
    deletedEmails.add(email);
    return nextResult;
  }

  @override
  void clearGuestData() => guestDataCleared = true;
}
