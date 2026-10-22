import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/reset_password_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/auth_page_fakes.dart';

AuthCubit _cubit(AuthPageFakeAuthRepository auth) => AuthCubit(
      authRepository: auth,
      profileRepository: const AuthPageFakeProfileRepository(),
    );

GoRouter _router(AuthCubit cubit) => GoRouter(
      initialLocation: '/reset-password',
      routes: [
        GoRoute(
          path: '/reset-password',
          builder: (_, __) => BlocProvider.value(
            value: cubit,
            child: const ResetPasswordPage(),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME_SCREEN')),
        ),
      ],
    );

Widget _app(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

Future<void> _baselineCubit(AuthCubit cubit) => cubit.checkSession();

Future<void> _enterPasswords(
  WidgetTester tester, {
  String password = 'newpass123',
  String? confirm,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), password);
  await tester.enterText(find.byType(TextFormField).at(1), confirm ?? password);
  await tester.pump();
}

Future<void> _tapUpdate(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Update Password'));
  await tester.pumpAndSettle();
}

void main() {
  group('ResetPasswordPage', () {
    testWidgets('renders the reset form', (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await _baselineCubit(cubit);
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      expect(find.text('New Password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
          find.widgetWithText(FilledButton, 'Update Password'), findsOneWidget);
    });

    testWidgets('the visibility toggle reveals both password fields',
        (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await _baselineCubit(cubit);
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      List<bool> obscured() => tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.obscureText)
          .toList();

      expect(obscured(), [true, true]);
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      expect(obscured(), [false, false]);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(obscured(), [true, true]);
    });

    testWidgets('a short password blocks submission', (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await _baselineCubit(cubit);
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterPasswords(tester, password: 'short');
      await _tapUpdate(tester);

      expect(
          find.text('Password must be at least 8 characters'), findsOneWidget);
      expect(auth.updateCalls, isEmpty);
    });

    testWidgets('a mismatched confirmation blocks submission', (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await _baselineCubit(cubit);
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterPasswords(tester,
          password: 'newpass123', confirm: 'newpass124');
      await _tapUpdate(tester);

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(auth.updateCalls, isEmpty);
    });

    testWidgets('a valid submit updates the password and lands home',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await _baselineCubit(cubit);
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterPasswords(tester);
      await _tapUpdate(tester);

      expect(auth.updateCalls, ['newpass123']);
      expect(find.text('HOME_SCREEN'), findsOneWidget);
      expect(find.text('Password updated successfully'), findsOneWidget);
    });

    testWidgets(
        'an already-authenticated recovery session keeps the form '
        'until the user submits', (tester) async {
      final auth = AuthPageFakeAuthRepository()
        ..sessionUser = const Authenticated('recovery-user');
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      // The initial state still renders the in-flight spinner, so settle
      // only after the session check moves the cubit to a terminal state.
      await tester.pump();

      // The recovery link completes sign-in while the page is open: the
      // form must stay put (no success copy, no bounce home).
      await cubit.checkSession();
      await tester.pumpAndSettle();

      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Password updated successfully'), findsNothing);
      expect(find.text('HOME_SCREEN'), findsNothing);

      await _enterPasswords(tester);
      await _tapUpdate(tester);

      expect(auth.updateCalls, ['newpass123']);
      expect(find.text('HOME_SCREEN'), findsOneWidget);
      expect(find.text('Password updated successfully'), findsOneWidget);
    });

    testWidgets('the update button is disabled while the call is in flight',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      auth.pendingUpdate = Completer<Result<void>>();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await _baselineCubit(cubit);
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterPasswords(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Update Password'));
      await tester.pump();

      expect(cubit.state.status, AuthStatus.authenticating);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.pendingUpdate!
          .complete(const Failure(AppError('stop', code: kFailureUnexpected)));
      await tester.pumpAndSettle();
    });

    testWidgets('a coded failure shows localized copy, not provider prose',
        (tester) async {
      final auth = AuthPageFakeAuthRepository(
        updateResult: const Failure(
          AppError('provider prose', code: kAuthWeakPassword),
        ),
      );
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await _baselineCubit(cubit);
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterPasswords(tester);
      await _tapUpdate(tester);

      expect(
          find.text('Password must be at least 8 characters'), findsOneWidget);
      expect(find.text('provider prose'), findsNothing);
      expect(find.text('HOME_SCREEN'), findsNothing);
    });
  });
}
