import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/onboarding_repository.dart';

final class LocalOnboardingRepository implements OnboardingRepository {
  LocalOnboardingRepository(this._preferences);

  static const _completedKey = 'onboarding_completed';

  final SharedPreferences _preferences;

  @override
  Future<Result<bool>> hasCompleted() async {
    try {
      return Success(_preferences.getBool(_completedKey) ?? false);
    } catch (error) {
      return Failure(
          AppError('Unable to read onboarding state.', cause: error));
    }
  }

  @override
  Future<Result<void>> complete() async {
    try {
      final didPersist = await _preferences.setBool(_completedKey, true);
      return didPersist
          ? const Success(null)
          : const Failure(AppError('Unable to save onboarding state.'));
    } catch (error) {
      return Failure(
          AppError('Unable to save onboarding state.', cause: error));
    }
  }
}
