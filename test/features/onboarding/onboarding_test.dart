import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/onboarding/data/local_onboarding_repository.dart';
import 'package:al_batal_elite/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_state.dart';

final class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository({this.completed = false});

  bool completed;
  bool completeCalled = false;

  @override
  Future<Result<bool>> hasCompleted() async => Success(completed);

  @override
  Future<Result<void>> complete() async {
    completeCalled = true;
    completed = true;
    return const Success(null);
  }
}

void main() {
  group('LocalOnboardingRepository', () {
    test('returns false when completion has not been persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = LocalOnboardingRepository(preferences);

      final result = await repository.hasCompleted();

      expect(result, isA<Success<bool>>());
      expect((result as Success<bool>).value, isFalse);
    });

    test('persists completion for the next app launch', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = LocalOnboardingRepository(preferences);

      await repository.complete();

      final result = await repository.hasCompleted();
      expect((result as Success<bool>).value, isTrue);
    });
  });

  group('OnboardingCubit', () {
    test('routes a first-time user to onboarding', () async {
      final cubit = OnboardingCubit(_FakeOnboardingRepository());
      addTearDown(cubit.close);

      await cubit.resolveDestination();

      expect(cubit.state.status, OnboardingStatus.ready);
      expect(cubit.state.destination, OnboardingDestination.onboarding);
    });

    test('routes a completed user to home', () async {
      final cubit = OnboardingCubit(_FakeOnboardingRepository(completed: true));
      addTearDown(cubit.close);

      await cubit.resolveDestination();

      expect(cubit.state.destination, OnboardingDestination.home);
    });

    test('completion persists and routes to home', () async {
      final repository = _FakeOnboardingRepository();
      final cubit = OnboardingCubit(repository);
      addTearDown(cubit.close);

      await cubit.complete();

      expect(repository.completeCalled, isTrue);
      expect(cubit.state.status, OnboardingStatus.ready);
      expect(cubit.state.destination, OnboardingDestination.home);
    });
  });
}
