part of '../auth_cubit.dart';

/// Device-local snapshot wipe for sign-out / account deletion.
///
/// Removes on-device address and order snapshots so a signed-out or
/// deleted device holds no personal data (audit S9). Calls the same
/// local stores the app reads from — never raw prefs keys. Cart and
/// wishlist are deliberately untouched here: they are guest-accessible
/// and the settings page already owns their wipe (same UX-043 lane).
///
/// Each wipe is retried once on failure and a still-failing wipe is
/// re-scheduled fire-and-forget so transient platform errors don't
/// leave PII behind; signOut/deleteAccount never abort on wipe failure.
extension AuthSnapshotWipe on AuthCubit {
  Future<void> clearLocalSnapshots() async {
    final addressRepository = _addressRepository;
    if (addressRepository is ClearableAddressRepository) {
      var result = await addressRepository.clearAddresses();
      if (result case Failure(error: final clearError)) {
        Log.w('Address snapshot clear failed (retrying): ${clearError.message}',
            category: LogCategory.auth);
        result = await addressRepository.clearAddresses();
        if (result case Failure(error: final retryError)) {
          Log.w('Address snapshot clear retry failed: ${retryError.message}',
              category: LogCategory.auth);
          // Schedule a late retry — best-effort PII re-wipe.
          unawaited(addressRepository.clearAddresses());
        }
      }
    }
    // Contained like the address clear above: a platform failure wiping
    // the orders snapshot must never abort signOut or deleteAccount —
    // those flows still need to reach emit(unauthenticated).
    try {
      await _orderSnapshots?.clearOrderSnapshots();
    } catch (_) {
      Log.w('clearOrders failed during snapshot wipe (retrying)',
          category: LogCategory.auth);
      try {
        await _orderSnapshots?.clearOrderSnapshots();
      } catch (_) {
        Log.w('clearOrders retry failed during snapshot wipe',
            category: LogCategory.auth);
        unawaited(
          Future(() => _orderSnapshots?.clearOrderSnapshots()).catchError(
            (_) => null,
          ),
        );
      }
    }
  }
}
