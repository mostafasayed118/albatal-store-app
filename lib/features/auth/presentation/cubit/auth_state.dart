import 'package:equatable/equatable.dart';

import '../../../../core/entities/profile.dart';

/// Auth flow states — extracted from `auth_cubit.dart` (no signature
/// changes; import the cubit file, which re-exports this).
enum AuthStatus {
  initial,
  checkingSession,
  unauthenticated,
  authenticating,
  authenticated,
  passwordRecovery,
  failure,
}

final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.errorMessage,
    this.errorCode,
  });

  final AuthStatus status;
  final Profile? profile;
  final String? errorMessage;

  /// Machine-readable class of [errorMessage] (see `failure_codes.dart`). The
  /// pages localize on this and never on the English text (audit 2026-09-19,
  /// sweep part 32).
  final String? errorCode;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isGuest => status == AuthStatus.unauthenticated;
  bool get isLoading =>
      status == AuthStatus.initial ||
      status == AuthStatus.checkingSession ||
      status == AuthStatus.authenticating;

  AuthState copyWith({
    AuthStatus? status,
    Profile? profile,
    String? errorMessage,
    String? errorCode,
    bool clearProfile = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        profile: clearProfile ? null : (profile ?? this.profile),
        errorMessage: errorMessage,
        errorCode: errorCode,
      );

  @override
  List<Object?> get props => [status, profile, errorMessage, errorCode];
}
