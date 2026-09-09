import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/onboarding_repository.dart';

final class LocalOnboardingRepository implements OnboardingRepository {
  LocalOnboardingRepository(this._preferences);

  static const _completedKey = 'onboarding_completed';

  final SharedPreferences _preferences;

  @override
  Future<Result<bool>> hasCompleted() => Result.guard(
        () async => _preferences.getBool(_completedKey) ?? false,
        'Unable to read onboarding state.',
      );

  @override
  Future<Result<void>> complete() async {
    final result = await Result.guard(
      () => _preferences.setBool(_completedKey, true),
      'Unable to save onboarding state.',
    );
    return result.when(
      success: (didPersist) => didPersist
          ? const Success(null)
          : const Failure(AppError('Unable to save onboarding state.')),
      failure: (error) => Failure(error),
    );
  }
}
