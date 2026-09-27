import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingOnboardingRepo implements OnboardingRepository {
  @override
  Future<Result<bool>> hasCompleted() async =>
      const Failure(AppError('storage down', code: 'onboarding_load_failed'));

  @override
  Future<Result<void>> complete() async =>
      const Failure(AppError('storage down', code: 'onboarding_save_failed'));
}

/// Batch 1 regression guard: onboarding failures carry a stable code for
/// localization instead of a diagnosis-only English message.
void main() {
  test('resolveDestination failure carries the error code', () async {
    final cubit = OnboardingCubit(_FailingOnboardingRepo());
    await cubit.resolveDestination();

    expect(cubit.state.status, OnboardingStatus.failure);
    expect(cubit.state.errorCode, 'onboarding_load_failed');
    expect(cubit.state.errorMessage, isNotNull);
    await cubit.close();
  });

  test('complete failure carries the error code', () async {
    final cubit = OnboardingCubit(_FailingOnboardingRepo());
    await cubit.complete();

    expect(cubit.state.status, OnboardingStatus.failure);
    expect(cubit.state.errorCode, 'onboarding_save_failed');
    await cubit.close();
  });
}
