import '../../../../core/error/result.dart';

/// Abstraction for the first-run onboarding gate.
///
/// One boolean of session state: has the user seen (and completed) the
/// welcome carousel. Kept in the domain layer so the splash/router path
/// consults a contract, not a storage implementation; the [Result]
/// boundary lets a storage failure fail safe (treated as not completed)
/// without leaking exceptions into the router.
abstract interface class OnboardingRepository {
  /// Whether onboarding has already been completed on this device.
  Future<Result<bool>> hasCompleted();

  /// Marks onboarding complete — irreversible for the install.
  Future<Result<void>> complete();
}
