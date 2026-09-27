import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_wishlist_sync_remote.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/auth_session_port.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_sync_remote.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocal implements WishlistRepository {
  _FakeLocal([Set<String>? seed]) : ids = {...?seed};

  Set<String> ids;
  var failReads = false;
  var failWrites = false;
  var writeCalls = 0;

  @override
  Future<Result<Set<String>>> readWishlist() async => failReads
      ? const Failure(AppError('nope', code: kFailureLoad))
      : Success({...ids});

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async {
    writeCalls++;
    if (failWrites) {
      return const Failure(AppError('nope', code: kFailureSave));
    }
    this.ids = {...ids};
    return const Success(null);
  }
}

class _FakeRemote implements WishlistSyncRemote {
  _FakeRemote([Set<String>? server]) : server = {...?server};

  Set<String> server;
  var fail = false;
  var calls = 0;
  Set<String>? lastPushed;

  @override
  Future<Set<String>> syncWishlist(Set<String> localIds) async {
    calls++;
    lastPushed = {...localIds};
    // Exception (not Error): mirrors a PostgrestException transport
    // failure — the repository catches `on Exception` by convention.
    if (fail) throw Exception('network down');
    server = {...server, ...localIds};
    return {...server};
  }
}

class _FakeSession implements AuthSessionPort {
  _FakeSession(this.email);

  final String? email;

  @override
  String? currentUserEmail() => email;
}

SupabaseWishlistRepository _repo({
  Set<String>? local,
  Set<String>? server,
  String? email,
  bool remoteFails = false,
  bool localReadFails = false,
  bool localWriteFails = false,
}) {
  final l = _FakeLocal(local)
    ..failReads = localReadFails
    ..failWrites = localWriteFails;
  final r = _FakeRemote(server)..fail = remoteFails;
  return SupabaseWishlistRepository(
    local: l,
    remote: r,
    session: _FakeSession(email),
  );
}

/// Wishlist sync (Batch 3 #6, migration 075): decorator + wire-shape guards.
void main() {
  group('parseWishlistIds', () {
    test('decodes a UUID array payload', () {
      expect(parseWishlistIds(['a', 'b', 'a']), {'a', 'b'});
    });

    test('drops blanks, non-strings, and non-list shapes', () {
      expect(parseWishlistIds(['a', '', 42, null]), {'a'});
      expect(parseWishlistIds(null), isEmpty);
      expect(parseWishlistIds({'ids': []}), isEmpty);
      expect(parseWishlistIds('a'), isEmpty);
    });
  });

  group('SupabaseWishlistRepository — guest (signed out)', () {
    test('read returns local without touching remote', () async {
      final local = _FakeLocal({'p1'});
      final remote = _FakeRemote({'p2'});
      final repo = SupabaseWishlistRepository(
        local: local,
        remote: remote,
        session: _FakeSession(null),
      );
      final result = await repo.readWishlist();
      expect(result, isA<Success<Set<String>>>());
      expect((result as Success<Set<String>>).value, {'p1'});
      expect(remote.calls, 0);
    });

    test('write persists local without touching remote', () async {
      final local = _FakeLocal();
      final remote = _FakeRemote();
      final repo = SupabaseWishlistRepository(
        local: local,
        remote: remote,
        session: _FakeSession(null),
      );
      final result = await repo.writeWishlist({'p1'});
      expect(result, isA<Success<void>>());
      expect(local.ids, {'p1'});
      expect(remote.calls, 0);
    });
  });

  group('SupabaseWishlistRepository — signed in', () {
    test('read union-merges local into server and persists merged set',
        () async {
      final repo = _repo(local: {'p1'}, server: {'p2'}, email: 'a@b.c');
      final result = await repo.readWishlist();
      expect((result as Success<Set<String>>).value, {'p1', 'p2'});
    });

    test('read falls back to local when remote throws', () async {
      final repo = _repo(
          local: {'p1'}, server: {'p2'}, email: 'a@b.c', remoteFails: true);
      final result = await repo.readWishlist();
      // Offline-tolerant: local list, not an error — the cubit stays usable.
      expect((result as Success<Set<String>>).value, {'p1'});
    });

    test('read surfaces local failure when both layers fail', () async {
      final repo =
          _repo(email: 'a@b.c', remoteFails: true, localReadFails: true);
      final result = await repo.readWishlist();
      expect(result, isA<Failure<Set<String>>>());
      expect((result as Failure<Set<String>>).error.code, kFailureLoad);
    });

    test('write pushes to remote after local persist', () async {
      final local = _FakeLocal();
      final remote = _FakeRemote();
      final repo = SupabaseWishlistRepository(
        local: local,
        remote: remote,
        session: _FakeSession('a@b.c'),
      );
      final result = await repo.writeWishlist({'p1', 'p2'});
      expect(result, isA<Success<void>>());
      expect(local.ids, {'p1', 'p2'});
      expect(remote.lastPushed, {'p1', 'p2'});
    });

    test('write keeps local copy but reports sync-pending code', () async {
      final local = _FakeLocal();
      final remote = _FakeRemote()..fail = true;
      final repo = SupabaseWishlistRepository(
        local: local,
        remote: remote,
        session: _FakeSession('a@b.c'),
      );
      final result = await repo.writeWishlist({'p1'});
      expect(local.ids, {'p1'});
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error.code, kFailureSave);
    });

    test('write short-circuits remote when local persist fails', () async {
      final local = _FakeLocal()..failWrites = true;
      final remote = _FakeRemote();
      final repo = SupabaseWishlistRepository(
        local: local,
        remote: remote,
        session: _FakeSession('a@b.c'),
      );
      final result = await repo.writeWishlist({'p1'});
      expect(result, isA<Failure<void>>());
      expect(remote.calls, 0);
    });
  });
}
