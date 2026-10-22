import 'dart:async';

import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';

/// Profile double for the auth-page harnesses: always resolves to the
/// configured profile (null by default, which is a valid "no row yet").
class AuthPageFakeProfileRepository implements ProfileRepository {
  const AuthPageFakeProfileRepository([this.profile]);

  final Profile? profile;

  @override
  Future<Result<Profile?>> readProfile(String userId) async => Success(profile);

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

/// One recorded sign-up call, so page tests can assert the exact payload
/// the form forwarded (including trimming).
typedef AuthPageSignUpCall = ({
  String email,
  String password,
  String? fullName,
});

/// One recorded sign-in call (email is expected to be trimmed already).
typedef AuthPageSignInCall = ({String email, String password});

/// Recording auth double for the sign-up / forgot / reset page harnesses.
///
/// Results are mutable so a single test can flip the outcome without
/// rebuilding the harness. A non-null `pending*` completer holds the call
/// open, which is how the loading-state tests observe `authenticating`.
class AuthPageFakeAuthRepository implements AuthRepository {
  AuthPageFakeAuthRepository({
    this.signUpResult = const Success(ConfirmationRequired()),
    this.resetResult = const Success(null),
    this.updateResult = const Success(null),
  });

  Result<AuthOutcome> signUpResult;
  Result<void> resetResult;
  Result<void> updateResult;
  Result<Authenticated> signInResult = const Success(Authenticated('user-1'));

  Completer<Result<AuthOutcome>>? pendingSignUp;
  Completer<Result<void>>? pendingReset;
  Completer<Result<void>>? pendingUpdate;
  Completer<Result<Authenticated>>? pendingSignIn;

  final List<AuthPageSignUpCall> signUpCalls = <AuthPageSignUpCall>[];
  final List<String> resetCalls = <String>[];
  final List<String> updateCalls = <String>[];
  final List<AuthPageSignInCall> signInCalls = <AuthPageSignInCall>[];

  @override
  Future<Result<Authenticated?>> checkSession() async => const Success(null);

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    signUpCalls.add((email: email, password: password, fullName: fullName));
    return pendingSignUp?.future ??
        Future<Result<AuthOutcome>>.value(signUpResult);
  }

  @override
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  }) {
    signInCalls.add((email: email, password: password));
    return pendingSignIn?.future ??
        Future<Result<Authenticated>>.value(signInResult);
  }

  @override
  Future<Result<void>> resetPassword(String email) {
    resetCalls.add(email);
    return pendingReset?.future ?? Future<Result<void>>.value(resetResult);
  }

  @override
  Future<Result<void>> updatePassword(String newPassword) {
    updateCalls.add(newPassword);
    return pendingUpdate?.future ?? Future<Result<void>>.value(updateResult);
  }

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);

  @override
  Stream<Authenticated?> get authStateChanges =>
      const Stream<Authenticated?>.empty();
}
