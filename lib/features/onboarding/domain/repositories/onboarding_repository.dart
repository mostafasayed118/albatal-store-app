import '../../../../core/error/result.dart';

abstract interface class OnboardingRepository {
  Future<Result<bool>> hasCompleted();

  Future<Result<void>> complete();
}
