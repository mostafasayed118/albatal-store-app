import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/sign_in_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/oauth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/auth_page_fakes.dart';

class _FakeOAuthService implements OAuthService {
  _FakeOAuthService([this.result = const Success('ok')]);

  Result<String> result;
  final List<OAuthProvider> calls = <OAuthProvider>[];

  @override
  Future<Result<String>> signIn(OAuthProvider provider) async {
    calls.add(provider);
    return result;
  }
}

AuthCubit _cubit(AuthPageFakeAuthRepository auth) => AuthCubit(
      authRepository: auth,
      profileRepository: const AuthPageFakeProfileRepository(),
    );

GoRouter _router(AuthCubit cubit, {OAuthService? oauthService}) => GoRouter(
      initialLocation: '/sign-in',
      routes: [
        GoRoute(
          path: '/sign-in',
          builder: (_, __) => BlocProvider.value(
            value: cubit,
            child: SignInPage(oauthService: oauthService),
          ),
        ),
        GoRoute(
          path: '/sign-up',
          builder: (_, __) => const Scaffold(body: Text('SIGN_UP_SCREEN')),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const Scaffold(body: Text('FORGOT_SCREEN')),
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

Future<void> _enterCredentials(WidgetTester tester,
    {String email = 'a@b.com', String password = 'secret123'}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.pump();
}

Future<void> _tapSignIn(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign In'));
  await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
  await tester.pumpAndSettle();
}

void main() {
  group('SignInPage', () {
    testWidgets('renders the credential form and guest escape hatch',
        (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Google'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('the visibility toggle reveals the password field',
        (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      bool obscured() =>
          tester.widget<TextField>(find.byType(TextField).at(1)).obscureText;

      expect(obscured(), isTrue);
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      expect(obscured(), isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('invalid email and short password block submission',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterCredentials(tester, email: 'not-an-email', password: 'short');
      await _tapSignIn(tester);

      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(
          find.text('Password must be at least 8 characters'), findsOneWidget);
      expect(auth.signInCalls, isEmpty);
    });

    testWidgets('a valid submit forwards trimmed credentials and lands home',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterCredentials(tester, email: '  a@b.com  ');
      await _tapSignIn(tester);

      expect(auth.signInCalls, hasLength(1));
      expect(auth.signInCalls.single.email, 'a@b.com');
      expect(auth.signInCalls.single.password, 'secret123');
      expect(find.text('HOME_SCREEN'), findsOneWidget);
    });

    testWidgets('the done keyboard action also submits', (tester) async {
      final auth = AuthPageFakeAuthRepository();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterCredentials(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, hasLength(1));
      expect(find.text('HOME_SCREEN'), findsOneWidget);
    });

    testWidgets('the button is disabled while the sign-in is in flight',
        (tester) async {
      final auth = AuthPageFakeAuthRepository();
      auth.pendingSignIn = Completer<Result<Authenticated>>();
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterCredentials(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(cubit.state.status, AuthStatus.authenticating);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.pendingSignIn!
          .complete(const Failure(AppError('stop', code: kFailureUnexpected)));
      await tester.pumpAndSettle();
    });

    testWidgets('a coded sign-in failure shows localized copy', (tester) async {
      final auth = AuthPageFakeAuthRepository()
        ..signInResult = const Failure(
          AppError('provider prose', code: kAuthInvalidCredentials),
        );
      final cubit = _cubit(auth);
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await _enterCredentials(tester);
      await _tapSignIn(tester);

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(find.text('provider prose'), findsNothing);
      expect(find.text('HOME_SCREEN'), findsNothing);
    });

    testWidgets('without an OAuth service Google explains it is unavailable',
        (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in with this provider is unavailable.'),
          findsOneWidget);
    });

    testWidgets('iOS renders the Apple button and starts its OAuth flow',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final oauth = _FakeOAuthService();
        final cubit = _cubit(AuthPageFakeAuthRepository());
        addTearDown(cubit.close);
        await cubit.checkSession();
        final router = _router(cubit, oauthService: oauth);
        addTearDown(router.dispose);

        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();

        expect(find.text('Apple'), findsOneWidget);
        await tester.tap(find.text('Apple'));
        await tester.pumpAndSettle();

        expect(oauth.calls, [OAuthProvider.apple]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a successful OAuth hand-off leaves navigation to the stream',
        (tester) async {
      final oauth = _FakeOAuthService();
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit, oauthService: oauth);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();

      expect(oauth.calls, [OAuthProvider.google]);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('a cancelled OAuth hand-off shows the cancelled copy',
        (tester) async {
      final oauth = _FakeOAuthService(
        const Failure(AppError(kOAuthCancelled, code: kOAuthCancelled)),
      );
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit, oauthService: oauth);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in was cancelled.'), findsOneWidget);
    });

    testWidgets('an uncoded OAuth failure falls back to the unavailable copy',
        (tester) async {
      final oauth = _FakeOAuthService(const Failure(AppError('boom')));
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit, oauthService: oauth);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in with this provider is unavailable.'),
          findsOneWidget);
    });

    testWidgets('the forgot-password link pushes its route', (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('FORGOT_SCREEN'), findsOneWidget);
    });

    testWidgets('the sign-up link pushes its route', (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Sign Up'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('SIGN_UP_SCREEN'), findsOneWidget);
    });

    testWidgets('continue as guest goes home', (tester) async {
      final cubit = _cubit(AuthPageFakeAuthRepository());
      addTearDown(cubit.close);
      await cubit.checkSession();
      final router = _router(cubit);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(find.text('HOME_SCREEN'), findsOneWidget);
    });
  });
}
