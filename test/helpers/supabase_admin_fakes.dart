import 'dart:async';

import 'package:al_batal_elite/features/admin/data/supabase_admin_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fakes for the admin data layer's PostgREST reads.
///
/// WHY THIS IS SHARED RATHER THAN LOCAL
/// ------------------------------------
/// These lived inside `admin_customer_directory_test.dart` until the customer
/// directory needed a WIDGET test that asserts the filter string the repository
/// emits. That string is built in the DATA layer, so a widget test driving a
/// stubbed `AdminRepository` stops one layer short of the thing under test: it
/// can prove the page hands down a term, but not what the term becomes on the
/// wire. Waiting for the assertion to reach the repository means the repository
/// has to be real, which means these fakes have to be reachable from a second
/// test file.
///
/// One home on purpose. A second, purpose-built fake client in the widget test
/// would be smaller today and would drift from this one — and the drift would
/// be invisible, because each fake would still satisfy its own test.

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Awaitable terminal builder (the repository `await`s the chain).
class FakeTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  FakeTransformBuilder(this._value, {this.total = 0});

  final T _value;

  /// Exact row count the server reports for the same filter — what
  /// `Prefer: count=exact` adds to the response.
  final int total;

  /// The `limit` the repository asked for, in order (a list rather than a
  /// mutable field because [Fake] is `@immutable`).
  ///
  /// Paging is positional now, so this is the page's *size* rather than a
  /// window into an offset — hence one more than a page: the look-ahead row is
  /// how "is there more?" is answered without a second request.
  final List<int> limits = [];

  /// The `order` clauses applied, in order, so a test can pin that the sort is
  /// TOTAL — `created_at` *and* the `id` tiebreaker keyset paging needs.
  final List<String> orders = [];

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    orders.add(column);
    return this;
  }

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) {
    limits.add(count);
    return this;
  }

  @override
  ResponsePostgrestBuilder<PostgrestResponse<T>, T, T> count([
    CountOption count = CountOption.exact,
  ]) =>
      FakeResponseBuilder<T>(_value, total);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
          {Function? onError}) =>
      Future.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future.value(_value).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_value).whenComplete(action);

  @override
  Stream<T> asStream() => Future.value(_value).asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future.value(_value).timeout(timeLimit, onTimeout: onTimeout);
}

/// Awaiting a counted request yields a [PostgrestResponse] carrying both the
/// page and the total — the whole point of asking for an exact count.
class FakeResponseBuilder<T> extends Fake
    implements ResponsePostgrestBuilder<PostgrestResponse<T>, T, T> {
  FakeResponseBuilder(this._data, this._count);

  final T _data;
  final int _count;

  PostgrestResponse<T> get _response =>
      PostgrestResponse<T>(data: _data, count: _count);

  @override
  Future<R> then<R>(FutureOr<R> Function(PostgrestResponse<T> value) onValue,
          {Function? onError}) =>
      Future.value(_response).then(onValue, onError: onError);

  @override
  Future<PostgrestResponse<T>> catchError(Function onError,
          {bool Function(Object error)? test}) =>
      Future.value(_response).catchError(onError, test: test);

  @override
  Future<PostgrestResponse<T>> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_response).whenComplete(action);

  @override
  Stream<PostgrestResponse<T>> asStream() => Future.value(_response).asStream();

  @override
  Future<PostgrestResponse<T>> timeout(Duration timeLimit,
          {FutureOr<PostgrestResponse<T>> Function()? onTimeout}) =>
      Future.value(_response).timeout(timeLimit, onTimeout: onTimeout);
}

/// `select()` returns a `PostgrestFilterBuilder`, which is NOT a subtype of
/// the transform builder, so it needs its own fake that hands back one.
class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  FakeFilterBuilder(this._rows, {this.total = 0});

  /// Exact match count the server reports alongside the page.
  final int total;

  /// Server-side filters the repository applied, as (operator, column,
  /// pattern) — evidence that the search is not done client-side.
  final List<(String, String, String)> filters = [];

  /// `or` trees the repository applied, kept verbatim. The *syntax* is the
  /// thing under test: PostgREST parses this string by hand, so a test pins
  /// the exact characters rather than a re-rendered equivalent.
  final List<String> orFilters = [];

  /// The transform builder the chain continues onto, so tests can read the
  /// page window it recorded. Built once and handed back by both `order` and
  /// `limit`, which is also why it is `late final` rather than a mutable
  /// field on an immutable fake.
  late final FakeTransformBuilder<T> transform =
      FakeTransformBuilder<T>(_typed, total: total);

  /// `dynamic` element type on purpose: the total-decode regression tests
  /// deliberately plant mistyped rows (e.g. a bare String) to prove they
  /// degrade to skips instead of throwing.
  final List<dynamic> _rows;

  /// Tolerantly reified row list: PostgREST row lists decode as JSON
  /// objects, so anything that is not a map is dropped here (mirroring the
  /// client) while mistyped FIELD values still reach the repository to
  /// prove its total-decode guards. Produces an honest
  /// `List<Map<String, dynamic>>` at runtime so `as T` (PostgrestList)
  /// succeeds.
  T get _typed => _rows.whereType<Map<String, dynamic>>().toList() as T;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object? value) => this;

  @override
  PostgrestFilterBuilder<T> or(String filters, {String? referencedTable}) {
    orFilters.add(filters);
    return this;
  }

  @override
  PostgrestFilterBuilder<T> ilike(String column, String pattern) {
    filters.add(('ilike', column, pattern));
    return this;
  }

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    // Recorded here as well as on the transform: the repository chains
    // `order` twice, and the first call is the one that leaves this builder.
    transform.orders.add(column);
    return transform;
  }

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      transform;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
          {Function? onError}) =>
      Future.value(_typed).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future.value(_typed).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_typed).whenComplete(action);

  @override
  Stream<T> asStream() => Future.value(_typed).asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future.value(_typed).timeout(timeLimit, onTimeout: onTimeout);
}

/// `rpc()` hands back a `PostgrestFilterBuilder` carrying a single decoded
/// JSON payload (not a row list), so the fakes above need an Object?-shaped
/// sibling for the `get_order_details` tests.
class FakeRpcBuilder extends Fake implements PostgrestFilterBuilder<Object?> {
  FakeRpcBuilder(this._payload);

  final Object? _payload;

  @override
  Future<R> then<R>(FutureOr<R> Function(Object? value) onValue,
          {Function? onError}) =>
      Future.value(_payload).then(onValue, onError: onError);

  @override
  Future<Object?> catchError(Function onError,
          {bool Function(Object error)? test}) =>
      Future.value(_payload).catchError(onError, test: test);

  @override
  Future<Object?> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_payload).whenComplete(action);

  @override
  Stream<Object?> asStream() => Future.value(_payload).asStream();
}

/// Repository whose profiles read answers with [rows] and a server total of
/// [total], plus the filter builder so a test can read the page window and
/// any server-side filter it recorded.
///
/// The `select(...)` stub is exact — it matches the precise column list the
/// repository MUST request. Any drift (including re-adding the nonexistent
/// `profiles.email`, the original regression) misses the stub, so the read
/// throws and the repository maps it to a `Failure`, which is what the tests
/// assert against.
(SupabaseAdminRepository, FakeFilterBuilder<PostgrestList>) directoryRepo({
  required List<dynamic> rows,
  int total = 0,
}) {
  final client = MockSupabaseClient();
  final builder = MockSupabaseQueryBuilder();
  when(() => client.from('profiles')).thenAnswer((_) => builder);
  final filters = FakeFilterBuilder<PostgrestList>(rows, total: total);
  when(() =>
          builder.select('id, full_name, phone, membership_tier, created_at'))
      .thenAnswer((_) => filters);
  return (SupabaseAdminRepository(client: client), filters);
}
