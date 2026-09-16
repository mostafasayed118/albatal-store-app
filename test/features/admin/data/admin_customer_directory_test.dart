import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/supabase_admin_repository.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression guards for the admin data layer.
///
/// The customer directory previously requested `email` from `profiles`, a
/// column that does not exist (the address lives in `auth.users`, which
/// PostgREST does not expose). PostgREST answered 42703, the repository
/// mapped it to `Failure`, and the Customers screen could never list anyone.
/// It stayed invisible because every existing test drove the page through a
/// STUB repository — the real `SupabaseAdminRepository` had no test at all.
///
/// `getOrderDetails` is covered for the same reason: its embedded
/// `profiles(...)` join is subject to the viewer's RLS, so it now goes through
/// the admin-checked `get_order_details` RPC instead.

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
/// JSON payload (not a row list), so the customer-directory fakes above need
/// an Object?-shaped sibling for the `get_order_details` tests.
class _FakeRpcBuilder extends Fake implements PostgrestFilterBuilder<Object?> {
  _FakeRpcBuilder(this._payload);

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

void main() {
  // ─── fetchCustomers ─────────────────────────────────────
  //
  // Regression guard (doc comment above): the directory once requested the
  // nonexistent `profiles.email` column; PostgREST answered 42703 and the
  // whole screen degraded to a permanent error. The stub below matches the
  // exact column list the repository MUST request — any drift (including
  // re-adding `email`) misses the stub and fails the test.
  /// Repository whose profiles read answers with [rows] and a server total of
  /// [total], plus the filter builder so a test can read the page window and
  /// any server-side filter it recorded.
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

  test('fetchCustomers asks for one page, newest first, and reports the total',
      () async {
    final (repo, filters) = directoryRepo(
      rows: [
        {
          'id': 'c1',
          'full_name': 'Layla',
          'phone': '01000000000',
          'membership_tier': 'premium',
          'created_at': '2026-09-16T10:00:00.000300Z',
        },
        {
          'id': 'c2',
          'full_name': 'Omar',
          'created_at': '2026-09-16T10:00:00.000200Z',
        },
      ],
      // The server holds far more rows than this page carries; that gap is
      // what the directory has to be able to state out loud.
      total: 120,
    );

    final result = await repo.fetchCustomers();

    // One page plus a look-ahead row, so "is there another page?" is answered
    // by the data itself. The old `.limit(500)` truncated the directory
    // silently and offered no way past it.
    expect(filters.transform.limits, [defaultCustomersPageSize + 1]);
    // The sort key has to be TOTAL. `created_at` alone is not unique — a seed,
    // a bulk import or two signups in the same tick share it — and a
    // non-unique key is exactly what lets a row land on two consecutive pages,
    // or on neither, once paging stops being offset-based.
    expect(filters.transform.orders, ['created_at', 'id']);
    final page = result.when(success: (v) => v, failure: (_) => null);
    expect(page, isNotNull,
        reason: 'the exact column list is the 42703 regression guard: any '
            'drift misses the stub and lands here as a Failure');
    expect(page!.total, 120, reason: 'total comes from the exact count');
    expect(page.customers.length, 2);
    expect(page.customers[0].id, 'c1');
    expect(page.customers[0].name, 'Layla');
    expect(page.customers[0].phone, '01000000000');
    expect(page.customers[0].contact, '01000000000'); // no email column → phone
    expect(page.customers[0].tier, 'premium');
    expect(page.customers[0].isBlocked, isFalse); // §14 read-only directory
    expect(page.customers[1].tier, 'standard'); // tolerant default
    expect(page.customers[1].phone, '');
    // A page that came back short IS the last page, and says so rather than
    // making the UI spend a request to discover the same thing.
    expect(page.nextCursor, isNull);
    // No search term means no server-side filter at all…
    expect(filters.filters, isEmpty);
    // …and no bookmark either: the first page starts at the newest row.
    expect(filters.orFilters, isEmpty);
  });

  test('fetchCustomers bookmarks the last row it actually returned', () async {
    final (repo, filters) = directoryRepo(rows: [
      {'id': 'c1', 'created_at': '2026-09-16T10:00:00.000300Z'},
      {'id': 'c2', 'created_at': '2026-09-16T10:00:00.000200Z'},
      // One row past the page: evidence that there is more, never a result.
      {'id': 'c3', 'created_at': '2026-09-16T10:00:00.000100Z'},
    ]);

    final page = (await repo.fetchCustomers(limit: 2))
        .when(success: (v) => v, failure: (_) => null)!;

    expect(page.customers.map((c) => c.id), ['c1', 'c2']);
    expect(
      page.nextCursor,
      (createdAt: '2026-09-16T10:00:00.000200Z', id: 'c2'),
      reason: 'the bookmark is the last RETURNED row, so the next page can '
          'neither repeat c2 nor skip it',
    );
    expect(filters.orFilters, isEmpty);
  });

  test('fetchCustomers resumes from the bookmark with a keyset filter',
      () async {
    final (repo, filters) = directoryRepo(rows: []);

    await repo.fetchCustomers(
      cursor: (createdAt: '2026-09-16T10:00:00.000200Z', id: 'c2'),
      limit: 2,
    );

    // The `id` clause is what makes the walk total. Drop it and two customers
    // created in the same tick can be ordered either way between two queries:
    // one of them then shows up twice, or not at all.
    expect(filters.orFilters, [
      'created_at.lt.2026-09-16T10:00:00.000200Z,'
          'and(created_at.eq.2026-09-16T10:00:00.000200Z,id.lt.c2)',
    ]);
    expect(filters.transform.limits, [3],
        reason: 'a continuation page is still a page plus one');
  });

  test('customerKeysetFilter covers ties on the sort key', () {
    expect(
      customerKeysetFilter(
          (createdAt: '2026-09-16T10:00:00.000200Z', id: 'c2')),
      'created_at.lt.2026-09-16T10:00:00.000200Z,'
      'and(created_at.eq.2026-09-16T10:00:00.000200Z,id.lt.c2)',
      reason: 'three clauses in two forms: strictly older, or the same '
          'instant and a lower id',
    );
  });

  test('fetchCustomers reports no total on a continuation page', () async {
    // A cursor narrows the filter the exact count is taken over, so the server
    // would be counting the rows REMAINING. Publishing that would make
    // "showing 50 of 120" turn into "showing 100 of 70" as the admin scrolled.
    final (repo, _) = directoryRepo(rows: [], total: 70);

    final page = (await repo.fetchCustomers(
            cursor: (createdAt: '2026-09-16T10:00:00Z', id: 'c2')))
        .when(success: (v) => v, failure: (_) => null)!;

    expect(page.total, isNull,
        reason: 'the cubit keeps the first page\'s total instead');
  });

  test('fetchCustomers normalises the bookmark timestamp to UTC', () async {
    // Newest first, as the server returns them, with a non-UTC offset.
    final (repo, _) = directoryRepo(rows: [
      {'id': 'c1', 'created_at': '2026-09-16T14:00:00.000500+02:00'},
      {'id': 'c2', 'created_at': '2026-09-16T13:00:00.000100+02:00'},
      {'id': 'c3', 'created_at': '2026-09-16T12:00:00.000100+02:00'},
    ]);

    final page = (await repo.fetchCustomers(limit: 2))
        .when(success: (v) => v, failure: (_) => null)!;

    // 13:00+02:00 is 11:00Z — and the microseconds survive the round trip. A
    // lost digit would move the boundary and repeat or drop the row it names.
    expect(
      page.nextCursor,
      (createdAt: '2026-09-16T11:00:00.000100Z', id: 'c2'),
    );
  });

  test('fetchCustomers stops paging when a row cannot anchor a bookmark',
      () async {
    // `profiles.created_at` is NOT NULL, so this is a defensive path. Resuming
    // from an invented position could repeat or skip rows, so ending the walk
    // is the safe answer.
    final (repo, _) = directoryRepo(rows: [
      {'id': 'c1'},
      {'id': 'c2'},
      {'id': 'c3'},
    ]);

    final page = (await repo.fetchCustomers(limit: 2))
        .when(success: (v) => v, failure: (_) => null)!;

    expect(page.customers.length, 2);
    expect(page.nextCursor, isNull);
  });

  test('fetchCustomers drops unnavigable rows before cutting the page',
      () async {
    final (repo, _) = directoryRepo(rows: [
      {'id': 'c1', 'created_at': '2026-09-16T10:00:00.000300Z'},
      {'id': 42, 'created_at': '2026-09-16T10:00:00.000200Z'}, // not a String
      {'id': '', 'created_at': '2026-09-16T10:00:00.000150Z'}, // empty
      {'id': 'c2', 'created_at': '2026-09-16T10:00:00.000100Z'},
      {'id': 'c3', 'created_at': '2026-09-16T10:00:00.000050Z'},
    ]);

    final page = (await repo.fetchCustomers(limit: 2))
        .when(success: (v) => v, failure: (_) => null)!;

    // A row nobody can navigate to must not occupy a slot, or the bookmark
    // would name a row that was never returned and the page would come up
    // short at the boundary.
    expect(page.customers.map((c) => c.id), ['c1', 'c2']);
    expect(
        page.nextCursor, (createdAt: '2026-09-16T10:00:00.000100Z', id: 'c2'));
  });

  test('fetchCustomers keeps the search filter on a continuation page',
      () async {
    final (repo, filters) = directoryRepo(rows: []);

    await repo.fetchCustomers(
      query: 'Layla',
      cursor: (createdAt: '2026-09-16T10:00:00Z', id: 'c2'),
    );

    // Paging must not quietly drop the search: the second page of a filtered
    // directory is a filtered directory, not the whole table. Both `or` params
    // ride along — the search tree, then the cursor.
    expect(filters.orFilters, [
      'full_name.ilike."%Layla%",phone.ilike."%Layla%"',
      'created_at.lt.2026-09-16T10:00:00Z,'
          'and(created_at.eq.2026-09-16T10:00:00Z,id.lt.c2)',
    ]);
  });

  test('fetchCustomers filters the search on the server, trimmed', () async {
    final (repo, filters) = directoryRepo(rows: []);

    await repo.fetchCustomers(query: '  Layla  ');

    expect(
        filters.orFilters, ['full_name.ilike."%Layla%",phone.ilike."%Layla%"'],
        reason: 'a search must narrow the query, not the loaded page');
  });

  test('fetchCustomers sends no filter for a blank search', () async {
    final (repo, filters) = directoryRepo(rows: []);

    await repo.fetchCustomers(query: '   ');

    expect(filters.filters, isEmpty);
    expect(filters.orFilters, isEmpty,
        reason: 'a blank search must not add an or tree of its own');
  });

  test('customerSearchPattern escapes LIKE metacharacters', () {
    expect(customerSearchPattern('sara'), '%sara%');
    // Unescaped, a bare `%` stands in for "any run of characters", so typing
    // it would return the whole table instead of narrowing it.
    expect(customerSearchPattern('%'), r'%\%%');
    expect(customerSearchPattern('a_b'), r'%a\_b%');
    expect(customerSearchPattern(r'a\b'), r'%a\\b%');
  });

  test('fetchCustomers escapes the term it hands to the server', () async {
    final (repo, filters) = directoryRepo(rows: []);

    await repo.fetchCustomers(query: '%');

    expect(
        filters.orFilters.single, r'full_name.ilike."%\%%",phone.ilike."%\%%"');
  });

  group('customerSearchFilter', () {
    test('searches name and phone as alternates', () {
      // Chained `.ilike()` calls would AND the columns, matching only a row
      // whose name *and* phone both contain the term — for a phone-shaped
      // query, the empty set.
      expect(customerSearchFilter('Layla'),
          'full_name.ilike."%Layla%",phone.ilike."%Layla%"');
    });

    test('routes a digit-only term to the normalised phone column', () {
      // `phone` stores whatever the customer typed, separators included, so a
      // digit-only search can only match the generated `phone_digits` column
      // (migration 065). The literal `phone` branch is not also emitted: for a
      // digit-only term it cannot match anything `phone_digits` does not.
      expect(
          customerSearchFilter('01012345678'),
          'full_name.ilike."%01012345678%",'
          'phone_digits.ilike."%01012345678%"');
    });

    test('normalises a term typed WITH separators down to its digits', () {
      // The admin reading a number back off a screen types the digits; the
      // customer typed the number with punctuation. Normalising only the
      // column would leave this case broken.
      expect(
          customerSearchFilter('+966 50 123-4567'),
          'full_name.ilike."%+966 50 123-4567%",'
          'phone_digits.ilike."%966501234567%"');
    });

    test('keeps a mixed alphanumeric term literal', () {
      // The shape gate is strict on purpose. Loosening it to "contains a
      // digit" would reduce `A1` to the digit `1`, matching almost every
      // row's phone and turning a typed name into a directory-wide result.
      expect(customerSearchFilter('A1'),
          'full_name.ilike."%A1%",phone.ilike."%A1%"');
      expect(customerSearchFilter('Branch 2'),
          'full_name.ilike."%Branch 2%",phone.ilike."%Branch 2%"');
    });

    test('quotes the value so a comma cannot split the or tree', () {
      // Unquoted, the comma would end the first condition and start a bogus
      // second one instead of narrowing the search.
      expect(customerSearchFilter('Smith, John'),
          'full_name.ilike."%Smith, John%",phone.ilike."%Smith, John%"');
    });

    test('quotes the value so parentheses cannot regroup the or tree', () {
      expect(customerSearchFilter('a(b)'),
          'full_name.ilike."%a(b)%",phone.ilike."%a(b)%"');
    });

    test('escapes a quote in the term so it cannot close the wrapper', () {
      expect(customerSearchFilter('a"b'),
          r'full_name.ilike."%a\"b%",phone.ilike."%a\"b%"');
    });

    test('applies LIKE escaping and or-tree quoting together', () {
      expect(customerSearchFilter('50% off, now'),
          r'full_name.ilike."%50\% off, now%",phone.ilike."%50\% off, now%"');
    });
  });

  group('customerPhoneDigitPattern', () {
    test('reduces a separator-laden number to its digits', () {
      expect(customerPhoneDigitPattern('+966 50 123 4567'), '%966501234567%');
      expect(customerPhoneDigitPattern('050-123-4567'), '%0501234567%');
      expect(customerPhoneDigitPattern('(010) 987/6543'), '%0109876543%');
    });

    test('passes a bare digit run through unchanged', () {
      expect(customerPhoneDigitPattern('01012345678'), '%01012345678%');
    });

    test('returns null for anything that is not digit-shaped', () {
      // null means "search the phone column literally instead".
      expect(customerPhoneDigitPattern(''), isNull);
      expect(customerPhoneDigitPattern('Layla'), isNull); // letters
      expect(customerPhoneDigitPattern('A1'), isNull); // contains a digit
      expect(customerPhoneDigitPattern('Branch 2'), isNull);
      expect(customerPhoneDigitPattern('50% off'), isNull); // LIKE metachar
      expect(customerPhoneDigitPattern('---'), isNull); // no digits at all
      expect(customerPhoneDigitPattern('()+'), isNull);
    });

    test('a LIKE metacharacter makes the term literal, not digit-shaped', () {
      // Which is exactly why the digit pattern needs no escaping of its own:
      // no metacharacter can get as far as being a phone-shaped term.
      expect(customerPhoneDigitPattern('50%'), isNull);
      expect(customerPhoneDigitPattern('a_b'), isNull);
      expect(customerPhoneDigitPattern(r'a\b'), isNull);
      expect(customerPhoneDigitPattern('+966%50'), isNull);
    });

    test('the middle of a returned pattern is nothing but digits', () {
      for (final term in [
        '+966 50 123 4567',
        '050-123-4567',
        '(010) 987/6543',
        '01012345678',
      ]) {
        final pattern = customerPhoneDigitPattern(term)!;
        expect(pattern, startsWith('%'));
        expect(pattern, endsWith('%'));
        expect(pattern.substring(1, pattern.length - 1),
            matches(RegExp(r'^[0-9]+$')),
            reason: '$term should reduce to digits only');
      }
    });
  });

  test('fetchCustomers maps a PostgREST failure to Failure (never throws)',
      () async {
    final client = MockSupabaseClient();
    final builder = MockSupabaseQueryBuilder();
    when(() => client.from('profiles')).thenAnswer((_) => builder);
    when(() =>
            builder.select('id, full_name, phone, membership_tier, created_at'))
        .thenThrow(Exception('42703 column profiles.email does not exist'));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.fetchCustomers();

    expect(
      result,
      isA<
          Failure<
              ({
                List<AdminCustomer> customers,
                int? total,
                CustomerCursor? nextCursor,
              })>>(),
    );
  });

  // ─── getOrderDetails ────────────────────────────────────
  //
  // Regression guard (doc comment above): the embedded profiles(...) join
  // was subject to the VIEWER's RLS and returned a null profile for every
  // other user's order. The detail path must go through the admin-checked
  // `get_order_details` RPC instead.
  test('getOrderDetails resolves through the admin-checked RPC', () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('get_order_details', params: {'p_order_id': 'o1'}))
        .thenAnswer(
      (_) => _FakeRpcBuilder({
        'order': {
          'id': 'o1',
          'status': 'placed',
          'total': 129000,
          'placed_at': '2026-09-01T10:00:00Z',
          'payment_method': 'card',
        },
        'items': [
          {
            'product_name': 'Silk',
            'size': '4m',
            'color': 'Navy',
            'quantity': 1,
            'unit_price': 129000,
          },
        ],
        'customer': {
          'id': 'c1',
          'full_name': 'Layla',
          'membership_tier': 'premium',
        },
      }),
    );
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.getOrderDetails('o1');

    verify(() => client.rpc('get_order_details', params: {'p_order_id': 'o1'}))
        .called(1);
    final order = result.when(success: (v) => v, failure: (_) => null);
    expect(order, isNotNull);
    expect(order!.id, 'o1');
    expect(order.status, AdminOrderStatus.placed);
    expect(order.total, const Money(129000));
    expect(order.customerId, 'c1');
    expect(order.customerName, 'Layla');
    expect(order.customerTier, 'premium');
    expect(order.items.length, 1);
    expect(order.itemCount, 1);
    expect(order.items.first.productName, 'Silk');
  });

  test('getOrderDetails degrades a missing order to Success(null)', () async {
    final client = MockSupabaseClient();
    when(() =>
            client.rpc('get_order_details', params: {'p_order_id': 'missing'}))
        .thenAnswer((_) => _FakeRpcBuilder(<String, dynamic>{}));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.getOrderDetails('missing');

    final order = result.when(success: (v) => v, failure: (_) => throw 'fail');
    expect(order, isNull);
  });

  test('getOrderDetails maps an RPC failure to Failure (never throws)',
      () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('get_order_details', params: {'p_order_id': 'o1'}))
        .thenThrow(Exception('permission'));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.getOrderDetails('o1');

    expect(result, isA<Failure<AdminOrder?>>());
  });

  // ─── fetchPendingReviews ────────────────────────────────
  //
  // Regression guard (v5 audit): the pending-queue decode used raw casts,
  // so ONE malformed row failed the entire list — the exact bug class the
  // total-decode convention (fetchCustomers, getAllOrders) was introduced
  // to kill. Mistyped rows must degrade to skips.
  test('fetchPendingReviews skips mistyped rows and maps the rest', () async {
    final client = MockSupabaseClient();
    final builder = MockSupabaseQueryBuilder();
    when(() => client.from('product_reviews')).thenAnswer((_) => builder);
    when(() => builder.select('id, product_id, text, rating'))
        .thenAnswer((_) => FakeFilterBuilder<PostgrestList>([
              {
                'id': 'r1',
                'product_id': 'p1',
                'text': 'Luxurious drape',
                'rating': 5,
              },
              'not-a-map', // mistyped row: degrade to skip, never throw
              {'id': 42, 'product_id': 'p2'}, // unusable id: skip
              {'id': 'r3', 'product_id': 7}, // unusable product: skip
              {'id': 'r4', 'product_id': 'p3', 'text': null, 'rating': 'x'},
            ]));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.fetchPendingReviews();

    verify(() => builder.select('id, product_id, text, rating')).called(1);
    final reviews = result.when(success: (v) => v, failure: (_) => null);
    expect(reviews, isNotNull);
    expect(reviews!.length, 2);
    expect(reviews[0].id, 'r1');
    expect(reviews[0].product, 'p1');
    expect(reviews[0].text, 'Luxurious drape');
    expect(reviews[0].rating, 5);
    expect(reviews[1].id, 'r4'); // text/rating degrade, row still usable
    expect(reviews[1].text, '');
    expect(reviews[1].rating, 0);
  });

  test('fetchPendingReviews filters to pending status and maps failure',
      () async {
    final client = MockSupabaseClient();
    final builder = MockSupabaseQueryBuilder();
    when(() => client.from('product_reviews')).thenAnswer((_) => builder);
    when(() => builder.select('id, product_id, text, rating'))
        .thenThrow(Exception('network'));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.fetchPendingReviews();

    expect(
      result,
      isA<
          Failure<
              List<({String id, String product, String text, int rating})>>>(),
    );
  });
}
