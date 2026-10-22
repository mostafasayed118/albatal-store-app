import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/forgot_password_page.dart';
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
      initialLocation: '/forgot-password',
      routes: [
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => BlocProvider.value(
            value: cubit,
            child: const ForgotPasswordPage(),
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (_, __) => const Scaffold(body: Text('SIGN_IN_SCREEN')),
        ),
      ],
    );

Widget _app(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

Future<void> _enterEmail(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField), email);
  await tester.pump();
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
  await tester.pumpAndSettle();
}

void main() {
  group('ForgotPasswordPage', () {
    testWidgets('renders the reset-email form', (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Send Reset Link'), findsOneWidget);
    });

    testWidgets('an invalid email blocks submission', (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterEmail(tester, 'not-an-email');
      await _tapSend(tester);

      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(auth.resetCalls, isEmpty);
    });

    testWidgets('a valid submit sends the trimmed email and goes to sign-in',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterEmail(tester, '  a@b.com  ');
      await _tapSend(tester);

      expect(auth.resetCalls, ['a@b.com']);
      expect(find.text('SIGN_IN_SCREEN'), findsOneWidget);
      expect(find.text('Check your email for the reset link'), findsOneWidget);
    });

    testWidgets('submitting from the keyboard action also sends the email',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterEmail(tester, 'a@b.com');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(auth.resetCalls, ['a@b.com']);
      expect(find.text('SIGN_IN_SCREEN'), findsOneWidget);
    });

    testWidgets('the send button is disabled while the call is in flight',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      auth.pendingReset = Completer<Result<void>>();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterEmail(tester, 'a@b.com');

      await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
      await tester.pump();

      expect(cubit.state.status, AuthStatus.authenticating);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.pendingReset!
          .complete(const Failure(AppError('stop', code: kFailureUnexpected)));
      await tester.pumpAndSettle();
    });

    testWidgets('a coded failure shows localized copy, not provider prose',
        (tester) async {
      final auth = AuthPageFakeAuthRepository(
        resetResult: const Failure(
          AppError('provider prose', code: kFailureNetwork),
        ),
      );
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterEmail(tester, 'a@b.com');
      await _tapSend(tester);

      expect(
          find.text('Connection problem. Please try again.'), findsOneWidget);
      expect(find.text('provider prose'), findsNothing);
      expect(find.text('SIGN_IN_SCREEN'), findsNothing);
    });
  });
}
