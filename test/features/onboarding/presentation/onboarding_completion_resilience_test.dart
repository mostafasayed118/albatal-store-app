import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:al_batal_elite/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Completion can be held open (double-submit probe) or failed on demand
/// (retry probe).
final class _ControlledOnboardingRepo implements OnboardingRepository {
  _ControlledOnboardingRepo({this.failures = 0});

  int failures;
  int completions = 0;
  bool hold = false;
  Completer<Result<void>>? pending;

  @override
  Future<Result<bool>> hasCompleted() async => const Success(false);

  @override
  Future<Result<void>> complete() {
    completions++;
    if (hold) {
      final completer = Completer<Result<void>>();
      pending = completer;
      return completer.future;
    }
    if (failures > 0) {
      failures--;
      return Future<Result<void>>.value(
        const Failure(AppError('offline', code: 'onboarding_complete_failed')),
      );
    }
    return Future<Result<void>>.value(const Success(null));
  }
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

GoRouter _router(OnboardingCubit cubit) => GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => BlocProvider.value(
            value: cubit,
            child: const OnboardingPage(),
          ),
        ),
        GoRoute(path: '/home', builder: (_, __) => const Text('home')),
      ],
    );

Future<void> _pumpPage(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('complete ignores re-entry while a completion is in flight', () async {
    final repo = _ControlledOnboardingRepo()..hold = true;
    final cubit = OnboardingCubit(repo);
    addTearDown(cubit.close);

    final first = cubit.complete();
    final second = cubit.complete();

    expect(repo.completions, 1,
        reason: 'a second tap must not duplicate the persist');
    expect(cubit.state.status, OnboardingStatus.completing);

    repo.pending!.complete(const Success(null));
    await first;
    await second;

    expect(cubit.state.status, OnboardingStatus.ready);
    expect(cubit.state.destination, OnboardingDestination.home);
  });

  testWidgets(
      'a failed completion surfaces an error with a retry that lands home',
      (tester) async {
    final repo = _ControlledOnboardingRepo(failures: 1);
    final cubit = OnboardingCubit(repo);
    final router = _router(cubit);
    addTearDown(() async {
      router.dispose();
      await cubit.close();
    });
    await _pumpPage(tester, router);

    await tester.ensureVisible(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(_path(router), '/onboarding');
    expect(repo.completions, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repo.completions, 2);
    expect(_path(router), '/home');
  });
}
