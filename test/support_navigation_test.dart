import 'dart:async';

import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/profile_page.dart';
import 'package:al_batal_elite/features/settings/data/local_settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/pages/settings_page.dart';
import 'package:al_batal_elite/features/support/data/local_support_repository.dart';
import 'package:al_batal_elite/features/support/presentation/pages/support_pages.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The /support route exists but had zero navigation call sites
/// (live-found 2026-09-04). These tests pin the entry points.
void main() {
  group('Support navigation', () {
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
      await authRepository.close();
    });

    GoRouter routerFor(String initial, List<RouteBase> extra) => GoRouter(
          initialLocation: initial,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => BlocProvider.value(
                value: authCubit,
                child: const ProfilePage(),
              ),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, __) => BlocProvider.value(
                value: _settingsCubit,
                child: BlocProvider.value(
                  // The settings page renders an account-deletion section
                  // gated on AuthCubit (UX-043); the no-session stub keeps
                  // it hidden in these navigation tests.
                  value: authCubit,
                  child: const SettingsPage(),
                ),
              ),
            ),
            GoRoute(
              path: '/support',
              builder: (_, __) =>
                  SupportPage(supportRepository: LocalSupportRepository()),
            ),
            ...extra,
          ],
        );

    Widget harness(GoRouter router) => MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        );

    testWidgets('authenticated profile links to support', (tester) async {
      authRepository.authChanges.add(const Authenticated('user-1'));
      final router = routerFor('/profile', const []);
      await tester.pumpWidget(harness(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Customer Support'));
      await tester.pumpAndSettle();

      expect(find.byType(SupportPage), findsOneWidget);
    });

    testWidgets('guest profile links to support', (tester) async {
      await authCubit.checkSession(); // -> unauthenticated guest view
      final router = routerFor('/profile', const []);
      await tester.pumpWidget(harness(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Customer Support'));
      await tester.pumpAndSettle();

      expect(find.byType(SupportPage), findsOneWidget);
    });

    testWidgets('profile links to settings (Stitch parity menu)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      _settingsCubit = SettingsCubit(LocalSettingsRepository(prefs));
      await _settingsCubit.load();
      addTearDown(_settingsCubit.close);

      authRepository.authChanges.add(const Authenticated('user-1'));
      final router = routerFor('/profile', const []);
      await tester.pumpWidget(harness(router));
      await tester.pumpAndSettle();

      // The settings row sits below the fold in the test viewport.
      await tester.ensureVisible(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('profile hides the badge for standard-tier customers',
        (tester) async {
      profileRepo.tier = MembershipTier.standard;
      authRepository.sessionUser = const Authenticated('user-1');
      await authCubit.checkSession();
      final router = routerFor('/profile', const []);
      await tester.pumpWidget(harness(router));
      await tester.pumpAndSettle();

      expect(find.text('Premium Member'), findsNothing);
      expect(find.byIcon(Icons.workspace_premium), findsNothing);
    });

    testWidgets('profile shows the Premium Member badge for premium tier',
        (tester) async {
      profileRepo.tier = MembershipTier.premium;
      authRepository.sessionUser = const Authenticated('user-1');
      await authCubit.checkSession();
      final router = routerFor('/profile', const []);
      await tester.pumpWidget(harness(router));
      await tester.pumpAndSettle();

      // ignore: avoid_print
      print(
          'DBG status=${authCubit.state.status} tier=${authCubit.state.profile?.tier} badge=${find.text('Premium Member').evaluate().length}');
      await tester.ensureVisible(find.text('Premium Member'));
      expect(find.text('Premium Member'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
    });

    testWidgets('settings links to support', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      _settingsCubit = SettingsCubit(LocalSettingsRepository(prefs));
      await _settingsCubit.load();
      addTearDown(_settingsCubit.close);

      final router = routerFor('/settings', const []);
      await tester.pumpWidget(harness(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Customer Support'));
      await tester.pumpAndSettle();

      expect(find.byType(SupportPage), findsOneWidget);
    });
  });
}

late SettingsCubit _settingsCubit;

final class _StubAuthRepository implements AuthRepository {
  final authChanges = StreamController<Authenticated?>.broadcast();

  /// When set, [checkSession] resolves with this session — the
  /// deterministic way to reach an authenticated profile (the stream
  /// listener path races under pumpAndSettle in widget tests).
  Authenticated? sessionUser;

  @override
  Stream<Authenticated?> get authStateChanges => authChanges.stream;

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

  Future<void> close() => authChanges.close();
}

final class _StubProfileRepository implements ProfileRepository {
  /// Tier served by [readProfile] — set per-test to drive badge parity.
  MembershipTier tier = MembershipTier.standard;

  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      Success(Profile(id: userId, tier: tier));

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}
