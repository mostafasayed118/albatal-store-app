import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/sign_in_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Hand-rolled stubs matching the project's test style (auth_cubit_test.dart):
/// the declared `mocktail` dev dep is intentionally unused to stay consistent.
class _StubAuthRepository implements AuthRepository {
  @override
  Future<Result<Authenticated?>> checkSession() async => const Success(null);

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async =>
      const Success(ConfirmationRequired());

  @override
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  }) async =>
      const Success(Authenticated('user-1'));

  @override
  Future<Result<void>> resetPassword(String email) async => const Success(null);

  @override
  Future<Result<void>> updatePassword(String newPassword) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Stream<Authenticated?> get authStateChanges =>
      const Stream<Authenticated?>.empty();
}

class _StubProfileRepository implements ProfileRepository {
  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      const Success(null);

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

Widget _app(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

GoRouter _router(AuthCubit authCubit, {String initialLocation = '/sign-in'}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/sign-in',
          builder: (_, __) => BlocProvider.value(
            value: authCubit,
            child: const SignInPage(),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (_, __) => const Scaffold(body: Text('CHECKOUT_SCREEN')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME_SCREEN')),
        ),
      ],
    );

Future<void> _submitCredentials(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sign-in returns the user to the redirect target after login',
      (WidgetTester tester) async {
    final authCubit = AuthCubit(
      authRepository: _StubAuthRepository(),
      profileRepository: _StubProfileRepository(),
    );
    // Resolve the cubit out of AuthStatus.initial (which counts as loading
    // and renders an infinite button spinner): stub has no session → guest.
    await authCubit.checkSession();
    addTearDown(authCubit.close);

    final router =
        _router(authCubit, initialLocation: '/sign-in?redirect=/checkout');
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(find.text('CHECKOUT_SCREEN'), findsNothing);

    await _submitCredentials(tester);

    // The router issued /sign-in?redirect=/checkout — after signing in the
    // user must land back on checkout, not on home.
    expect(find.text('CHECKOUT_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });

  testWidgets('sign-in without a redirect param lands on home',
      (WidgetTester tester) async {
    final authCubit = AuthCubit(
      authRepository: _StubAuthRepository(),
      profileRepository: _StubProfileRepository(),
    );
    await authCubit.checkSession();
    addTearDown(authCubit.close);

    final router = _router(authCubit);
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await _submitCredentials(tester);

    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.text('CHECKOUT_SCREEN'), findsNothing);
  });
}
