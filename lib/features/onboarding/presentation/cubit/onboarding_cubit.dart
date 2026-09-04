import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_state.dart';

final class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._repository) : super(const OnboardingState());

  final OnboardingRepository _repository;

  Future<void> resolveDestination() async {
    emit(state.copyWith(
      status: OnboardingStatus.loading,
      clearError: true,
    ));

    final result = await _repository.hasCompleted();
    result.when(
      success: (completed) => emit(state.copyWith(
        status: OnboardingStatus.ready,
        destination: completed
            ? OnboardingDestination.home
            : OnboardingDestination.onboarding,
      )),
      failure: (error) => emit(state.copyWith(
        status: OnboardingStatus.failure,
        errorMessage: error.message,
      )),
    );
  }

  Future<void> complete() async {
    emit(state.copyWith(
      status: OnboardingStatus.completing,
      clearError: true,
    ));

    final result = await _repository.complete();
    result.when(
      success: (_) => emit(state.copyWith(
        status: OnboardingStatus.ready,
        destination: OnboardingDestination.home,
      )),
      failure: (error) => emit(state.copyWith(
        status: OnboardingStatus.failure,
        errorMessage: error.message,
      )),
    );
  }
}
