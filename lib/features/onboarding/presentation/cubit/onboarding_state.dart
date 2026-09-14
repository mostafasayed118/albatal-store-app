import 'package:equatable/equatable.dart';

enum OnboardingStatus { initial, loading, ready, completing, failure }

enum OnboardingDestination { onboarding, home }

final class OnboardingState extends Equatable {
  const OnboardingState({
    this.status = OnboardingStatus.initial,
    this.destination,
    this.errorMessage,
    this.errorCode,
  });

  final OnboardingStatus status;
  final OnboardingDestination? destination;
  final String? errorMessage;

  /// Machine-readable error classification from [AppError.code] for
  /// UI localization (audit 2026-09-14); null when the failure carried
  /// no code — pages fall back to [errorMessage] verbatim.
  final String? errorCode;

  OnboardingState copyWith({
    OnboardingStatus? status,
    OnboardingDestination? destination,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      destination: destination ?? this.destination,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }

  @override
  List<Object?> get props => [status, destination, errorMessage, errorCode];
}
