import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:al_batal_elite/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:al_batal_elite/features/onboarding/presentation/pages/splash_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/remote_config_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class _OnboardingRepo implements OnboardingRepository {
  _OnboardingRepo({this.completed = false, this.fail = false});

  bool completed;
  bool fail;
  int completions = 0;

  @override
  Future<Result<bool>> hasCompleted() async => fail
      ? const Failure<bool>(AppError('read failed', code: 'read_failed'))
      : Success(completed);

  @override
  Future<Result<void>> complete() async {
    completions++;
    completed = true;
    return const Success(null);
  }
}

final class _Fetcher implements RemoteConfigFetcher {
  _Fetcher(this.values);
  final Map<String, String> values;

  @override
  Future<Map<String, String>> fetch() async => values;
}

final class _HangingFetcher implements RemoteConfigFetcher {
  final _completer = Completer<Map<String, String>>();

  @override
  Future<Map<String, String>> fetch() => _completer.future;
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  Future<GoRouter> pumpSplash(
    WidgetTester tester, {
    required _OnboardingRepo repo,
    RemoteConfigService? config,
  }) async {
    final cubit = OnboardingCubit(repo);
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
            path: '/splash',
            builder: (_, __) => BlocProvider.value(
                  value: cubit,
                  child: SplashPage(remoteConfig: config),
                )),
        GoRoute(path: '/onboarding', builder: (_, __) => const Text('intro')),
        GoRoute(path: '/home', builder: (_, __) => const Text('home')),
        GoRoute(
            path: '/maintenance',
            builder: (_, __) => const Text('maintenance')),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await cubit.close();
    });
    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pump();
    return router;
  }

  testWidgets('splash routes a first-time user to onboarding', (tester) async {
    final router = await pumpSplash(tester, repo: _OnboardingRepo());

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_path(router), '/onboarding');
  });

  testWidgets('maintenance mode gates the destination', (tester) async {
    final router = await pumpSplash(
      tester,
      repo: _OnboardingRepo(completed: true),
      config: RemoteConfigService(
          fetcher: _Fetcher({
        RemoteConfigService.keyMaintenanceMode: 'true',
      })),
    );

    await tester.pump(const Duration(milliseconds: 400));

    expect(_path(router), '/maintenance');
  });

  testWidgets('a required update gates the destination', (tester) async {
    final router = await pumpSplash(
      tester,
      repo: _OnboardingRepo(completed: true),
      config: RemoteConfigService(
        fetcher: _Fetcher({
          RemoteConfigService.keyMinSupportedVersion: '99.0.0',
        }),
        versionProvider: () async => '1.0.0',
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));

    expect(_path(router), '/maintenance');
  });

  testWidgets('a slow config fetch times out and falls back to defaults',
      (tester) async {
    final router = await pumpSplash(
      tester,
      repo: _OnboardingRepo(completed: true),
      config: RemoteConfigService(fetcher: _HangingFetcher()),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_path(router), '/home');
  });

  testWidgets('failure shows a retry action that re-resolves the destination',
      (tester) async {
    final repo = _OnboardingRepo(fail: true);
    final router = await pumpSplash(tester, repo: repo);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Retry'), findsOneWidget);

    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_path(router), '/onboarding');
  });

  testWidgets('onboarding skip completes and navigates home', (tester) async {
    final repo = _OnboardingRepo();
    final cubit = OnboardingCubit(repo);
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
            path: '/onboarding',
            builder: (_, __) => BlocProvider.value(
                  value: cubit,
                  child: const OnboardingPage(),
                )),
        GoRoute(path: '/home', builder: (_, __) => const Text('home')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(repo.completions, 1);
    expect(_path(router), '/home');
  });

  testWidgets('onboarding next advances slides and Get Started completes',
      (tester) async {
    final repo = _OnboardingRepo();
    final cubit = OnboardingCubit(repo);
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
            path: '/onboarding',
            builder: (_, __) => BlocProvider.value(
                  value: cubit,
                  child: const OnboardingPage(),
                )),
        GoRoute(path: '/home', builder: (_, __) => const Text('home')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
    await tester.ensureVisible(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(repo.completions, 1);
    expect(_path(router), '/home');
  });
}
