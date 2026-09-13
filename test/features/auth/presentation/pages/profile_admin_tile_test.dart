import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/profile_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The /admin route was router-gated on `profile.isAdmin` but had ZERO
/// navigation call sites (owner-found 2026-09-13) — admins could never
/// reach the dashboard. These tests pin the profile-page entry point:
/// rendered only for admins, tapping navigates to /admin (the router
/// redirect stays the real guard against non-admins).
void main() {
  late _StubAuthRepository authRepository;
  late AuthCubit authCubit;
  final profileRepo = _StubProfileRepository();

  setUp(() {
    authRepository = _StubAuthRepository();
    authCubit = AuthCubit(
      authRepository: authRepository,
      profileRepository: profileRepo,
    );
  });

  tearDown(() async {
    await authCubit.close();
  });

  GoRouter router() => GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, __) => BlocProvider.value(
              value: authCubit,
              child: const ProfilePage(),
            ),
          ),
          GoRoute(
            path: '/admin',
            builder: (_, __) => const Scaffold(body: Text('ADMIN_SCREEN')),
          ),
        ],
      );

  Widget harness() => MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router(),
      );

  testWidgets('admin profile shows the Admin Dashboard tile and navigates',
      (tester) async {
    profileRepo.isAdmin = true;
    authRepository.sessionUser = const Authenticated('user-1');
    await authCubit.checkSession();
    addTearDown(() {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Admin Dashboard'), findsOneWidget);

    await tester.ensureVisible(find.text('Admin Dashboard'));
    await tester.tap(find.text('Admin Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('ADMIN_SCREEN'), findsOneWidget);
  });

  testWidgets('non-admin profile hides the Admin Dashboard tile',
      (tester) async {
    profileRepo.isAdmin = false;
    authRepository.sessionUser = const Authenticated('user-1');
    await authCubit.checkSession();

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Admin Dashboard'), findsNothing);
  });
}

final class _StubAuthRepository implements AuthRepository {
  /// When set, [checkSession] resolves with this session — the
  /// deterministic way to reach an authenticated profile.
  Authenticated? sessionUser;

  @override
  Stream<Authenticated?> get authStateChanges =>
      const Stream<Authenticated?>.empty();

  @override
  Future<Result<Authenticated?>> checkSession() async => Success(sessionUser);

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
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);
}

final class _StubProfileRepository implements ProfileRepository {
  bool isAdmin = false;

  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      Success(Profile(id: userId, isAdmin: isAdmin));

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}
