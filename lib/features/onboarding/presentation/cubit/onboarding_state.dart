import 'package:equatable/equatable.dart';

enum OnboardingStatus { initial, loading, ready, completing, failure }

enum OnboardingDestination { onboarding, home }

final class OnboardingState extends Equatable {
  const OnboardingState({
    this.status = OnboardingStatus.initial,
    this.destination,
    this.errorMessage,
  });

  final OnboardingStatus status;
  final OnboardingDestination? destination;
  final String? errorMessage;

  OnboardingState copyWith({
    OnboardingStatus? status,
    OnboardingDestination? destination,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      destination: destination ?? this.destination,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, destination, errorMessage];
}
