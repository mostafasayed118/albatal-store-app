import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/sign_up_page.dart';
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
      initialLocation: '/sign-up',
      routes: [
        GoRoute(
          path: '/sign-up',
          builder: (_, __) => BlocProvider.value(
            value: cubit,
            child: const SignUpPage(),
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (_, __) => const Scaffold(body: Text('SIGN_IN_SCREEN')),
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

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Ahmed');
  await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
  await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
  await tester.enterText(find.byType(TextFormField).at(3), 'secret123');
  await tester.pump();
}

Future<void> _tapSignUp(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign Up'));
  await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
  await tester.pumpAndSettle();
}

void main() {
  group('signUpPasswordValidator', () {
    test('missing and too-short values use the too-short copy', () {
      expect(signUpPasswordValidator(null),
          'Password must be at least 8 characters');
      expect(signUpPasswordValidator('short'),
          'Password must be at least 8 characters');
      expect(signUpPasswordValidator(''),
          'Password must be at least 8 characters');
    });

    test('a provided too-short message wins over the fallback', () {
      expect(
        signUpPasswordValidator('123', tooShortMessage: 'TOO SHORT'),
        'TOO SHORT',
      );
    });

    test('rejects a letters-only password', () {
      expect(signUpPasswordValidator('longenough'),
          'Password must contain at least one letter and one digit');
    });

    test('rejects a digits-only password', () {
      expect(signUpPasswordValidator('12345678'),
          'Password must contain at least one letter and one digit');
    });

    test('a provided weak message wins over the fallback', () {
      expect(
        signUpPasswordValidator('12345678', tooWeakMessage: 'TOO WEAK'),
        'TOO WEAK',
      );
    });

    test('accepts a password with a letter, a digit and 8+ characters', () {
      expect(signUpPasswordValidator('secret123'), isNull);
      expect(signUpPasswordValidator('A1bcdefg'), isNull);
    });
  });

  group('SignUpPage', () {
    testWidgets('renders the sign-up form', (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.widgetWithText(FilledButton, 'Sign Up'), findsOneWidget);
      expect(find.text('Already have an account?'), findsOneWidget);
    });

    testWidgets('the visibility toggle reveals both password fields',
        (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      List<bool> obscured() => tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.obscureText)
          .toList();

      expect(obscured()[2], isTrue);
      expect(obscured()[3], isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(obscured()[2], isFalse);
      expect(obscured()[3], isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(obscured()[2], isTrue);
      expect(obscured()[3], isTrue);
    });

    testWidgets('empty submit surfaces the field validation errors',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _tapSignUp(tester);

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(find.text('Password must be at least 8 characters'), findsWidgets);
      expect(auth.signUpCalls, isEmpty);
    });

    testWidgets('a password without a digit never reaches the cubit',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ahmed');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'longenough');
      await tester.enterText(find.byType(TextFormField).at(3), 'longenough');
      await tester.pump();
      await _tapSignUp(tester);

      expect(
        find.text('Password must contain at least one letter and one digit'),
        findsOneWidget,
      );
      expect(auth.signUpCalls, isEmpty);
    });

    testWidgets('a mismatched confirmation blocks submission', (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ahmed');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret124');
      await tester.pump();
      await _tapSignUp(tester);

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(auth.signUpCalls, isEmpty);
    });

    testWidgets('a valid submit forwards trimmed values and lands home',
        (tester) async {
      final auth = AuthPageFakeAuthRepository(
        signUpResult: const Success(Authenticated('user-1')),
      );
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '  Ahmed  ');
      await tester.enterText(find.byType(TextFormField).at(1), '  a@b.com  ');
      await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret123');
      await tester.pump();
      await _tapSignUp(tester);

      expect(auth.signUpCalls, hasLength(1));
      expect(auth.signUpCalls.single.email, 'a@b.com');
      expect(auth.signUpCalls.single.fullName, 'Ahmed');
      expect(auth.signUpCalls.single.password, 'secret123');
      expect(find.text('HOME_SCREEN'), findsOneWidget);
    });

    testWidgets(
        'confirmation-required shows the verify snackbar and returns to sign-in',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _fillValidForm(tester);
      await _tapSignUp(tester);

      expect(auth.signUpCalls, hasLength(1));
      expect(find.text('SIGN_IN_SCREEN'), findsOneWidget);
      expect(
          find.text('Check your email to verify your account'), findsOneWidget);
    });

    testWidgets('a coded failure shows localized copy, not provider prose',
        (tester) async {
      final auth = AuthPageFakeAuthRepository(
        signUpResult: const Failure(
          AppError('provider prose', code: kAuthInvalidCredentials),
        ),
      );
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _fillValidForm(tester);
      await _tapSignUp(tester);

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(find.text('provider prose'), findsNothing);
      expect(find.text('SIGN_IN_SCREEN'), findsNothing);
    });

    testWidgets('the submit button is disabled while a sign-up is in flight',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      auth.pendingSignUp = Completer<Result<AuthOutcome>>();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _fillValidForm(tester);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign Up'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
      await tester.pump();

      expect(cubit.state.status, AuthStatus.authenticating);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.pendingSignUp!
          .complete(const Failure(AppError('stop', code: kFailureUnexpected)));
      await tester.pumpAndSettle();
    });

    testWidgets('the sign-in text button pushes the sign-in screen',
        (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(TextButton, 'Sign In'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('SIGN_IN_SCREEN'), findsOneWidget);
    });
  });
}
