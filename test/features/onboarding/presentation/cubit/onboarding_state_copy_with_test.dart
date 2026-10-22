import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith keeps the current status when none is given', () {
    const state = OnboardingState(
      status: OnboardingStatus.ready,
      errorMessage: 'boom',
      errorCode: 'E_BOOM',
    );

    final next = state.copyWith(destination: OnboardingDestination.home);

    expect(next.status, OnboardingStatus.ready);
    expect(next.destination, OnboardingDestination.home);
    expect(next.errorMessage, 'boom');
    expect(next.errorCode, 'E_BOOM');
  });

  test('copyWith can clear the error fields', () {
    const state = OnboardingState(
      status: OnboardingStatus.failure,
      errorMessage: 'boom',
      errorCode: 'E_BOOM',
    );

    final next = state.copyWith(clearError: true);

    expect(next.status, OnboardingStatus.failure);
    expect(next.errorMessage, isNull);
    expect(next.errorCode, isNull);
  });
}
