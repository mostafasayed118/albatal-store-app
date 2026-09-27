import '../../../core/error/app_error.dart';
import '../../../core/error/failure_codes.dart';
import '../../../core/error/result.dart';
import '../../../shared/services/logger.dart';
import '../domain/repositories/auth_session_port.dart';
import '../domain/repositories/wishlist_repository.dart';
import '../domain/repositories/wishlist_sync_remote.dart';

/// [WishlistRepository] with cross-device sync (Batch 3 #6).
///
/// Decorator over the local repository: guests (no session) behave
/// byte-identically to [local] — the sync path only engages when
/// [session] reports a signed-in user.
///
/// - `readWishlist`: pushes the local set through the merge RPC, persists
///   the merged server set locally, and returns it. Any remote failure
///   (offline, expired token, migration not yet applied) logs and falls
///   back to the local list — the wishlist stays usable offline.
/// - `writeWishlist`: writes locally first (offline source of truth),
///   then pushes best-effort when signed in. A remote failure surfaces
///   as [kFailureSave] so the UI warns sync is pending; the local copy
///   is intact and the next read heals the server.
final class SupabaseWishlistRepository implements WishlistRepository {
  SupabaseWishlistRepository({
    required WishlistRepository local,
    required WishlistSyncRemote remote,
    required AuthSessionPort session,
  })  : _local = local,
        _remote = remote,
        _session = session;

  final WishlistRepository _local;
  final WishlistSyncRemote _remote;
  final AuthSessionPort _session;

  bool get _signedIn => _session.currentUserEmail() != null;

  @override
  Future<Result<Set<String>>> readWishlist() async {
    final local = await _local.readWishlist();
    if (!_signedIn) return local;
    final localIds = switch (local) {
      Success(:final value) => value,
      Failure() => <String>{},
    };
    try {
      final merged = await _remote.syncWishlist(localIds);
      final persisted = await _local.writeWishlist(merged);
      return switch (persisted) {
        Success() => Success(merged),
        Failure(:final error) => Failure(error),
      };
    } on Exception catch (e) {
      Log.w('wishlist sync failed; using local list.',
          category: LogCategory.network, error: e);
      if (localIds.isNotEmpty) return Success(localIds);
      return local;
    }
  }

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async {
    final local = await _local.writeWishlist(ids);
    if (local is Failure) return local;
    if (!_signedIn) return local;
    try {
      await _remote.syncWishlist(ids);
      return local;
    } on Exception catch (e, st) {
      Log.w('wishlist push failed; will retry on next read.',
          category: LogCategory.network, error: e);
      return Failure(AppError(
        'Wishlist saved on this device; sync pending.',
        cause: e,
        stackTrace: st,
        code: kFailureSave,
      ));
    }
  }
}
