import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/settings/data/local_settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/pages/settings_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/memory_storefront_persistence.dart';
import 'helpers/stub_auth_repositories.dart';

/// The account-deletion confirm dialog (UX-043) must open reliably from the
/// settings row. Regression coverage for the on-device first-frame freeze
/// report (blank screen at ~3fps, first tap seemingly swallowed): the guard
/// waits for the tapped row's frame to settle before pushing the dialog and
/// defers keyboard focus until the dialog's first frame is on screen.
void main() {
  late _RecordingAuthRepository authRepository;
  late AuthCubit authCubit;
  late SettingsCubit settingsCubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    authRepository = _RecordingAuthRepository();
    authCubit = AuthCubit(
      authRepository: authRepository,
      profileRepository: StubProfileRepository(),
    );
    settingsCubit = SettingsCubit(LocalSettingsRepository(prefs));
    await settingsCubit.load();
    // Stub reports an existing session -> authenticated (delete row visible).
    await authCubit.checkSession();
  });

  tearDown(() async {
    await authCubit.close();
    await settingsCubit.close();
  });

  Widget harness() {
    final persistence = MemoryStorefrontPersistence();
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settingsCubit),
          BlocProvider.value(value: authCubit),
          BlocProvider(create: (_) => CartCubit(persistence)),
          BlocProvider(create: (_) => WishlistCubit(persistence)),
        ],
        child: const SettingsPage(),
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

    expect(authRepository.deletedEmails, ['ux043@example.com']);
    expect(find.text('Account deleted'), findsOneWidget);
  });
}

/// Authenticated stub that records every deleteAccount call.
final class _RecordingAuthRepository implements AuthRepository {
  final deletedEmails = <String>[];

  @override
  Stream<Authenticated?> get authStateChanges => const Stream.empty();

  @override
  Future<Result<Authenticated?>> checkSession() async =>
      const Success(Authenticated('user-1'));

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async =>
      const Failure(AppError('stub'));

  @override
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  }) async =>
      const Failure(AppError('stub'));

  @override
  Future<Result<void>> resetPassword(String email) async => const Success(null);

  @override
  Future<Result<void>> updatePassword(String newPassword) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> deleteAccount({required String email}) async {
    deletedEmails.add(email);
    return const Success(null);
  }
}
