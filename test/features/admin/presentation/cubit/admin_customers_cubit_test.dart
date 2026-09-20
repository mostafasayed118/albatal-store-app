import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_customers_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The customer directory cubit had no coverage at all before this file
/// (audit 2026-09-16, §14 follow-up). These are the first pins on it, and the
/// ones that matter most are the interleavings: paging plus live search makes
/// overlapping requests normal, so a superseded response must never be
/// applied.
class _MockAdminRepository extends Mock implements AdminRepository {}

typedef _Page = ({
  List<AdminCustomer> customers,
  int? total,
  CustomerCursor? nextCursor,
});

/// The bookmark naming [id]. The timestamp is fixed because these tests are
/// about *which* row the walk resumes from, not about the instant: the
/// repository is where the timestamp's meaning is pinned.
CustomerCursor _bookmark(String id) =>
    (createdAt: '2026-09-16T10:00:00.000000Z', id: id);

AdminCustomer _customer(
  String id,
  String name, {
  String tier = 'standard',
  String email = '',
  String phone = '',
}) =>
    AdminCustomer(
      id: id,
      name: name,
      email: email,
      phone: phone,
      tier: tier,
      isBlocked: false,
    );

final _sara = _customer('profile-9', 'Sara Ali', phone: '0100');
final _omar = _customer('profile-8', 'Omar Nabil', email: 'omar@batal.eg');
final _nour = _customer('profile-7', 'Nour Adel');
final _hoda = _customer('profile-6', 'Hoda Sami');

void main() {
  late _MockAdminRepository repo;

  setUp(() {
    repo = _MockAdminRepository();
  });

  /// Small pages and a zero debounce so tests drive paging without fifty-row
  /// fixtures and never wait out a real timer.
  AdminCustomersCubit buildCubit({int pageSize = 2}) => AdminCustomersCubit(
        repository: repo,
        pageSize: pageSize,
        searchDebounce: Duration.zero,
      );

  /// Lets a debounced search start and its (already stubbed) response land.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('AdminCustomersCubit.load', () {
    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'loads the first page and reports that the server holds more',
      build: () {
        when(() => repo.fetchCustomers(query: null, limit: 2))
            .thenAnswer((_) async => Success<_Page>((
                  customers: [_sara, _omar],
                  total: 5,
                  nextCursor: _bookmark('profile-8'),
                )));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminCustomersState>()
            .having((s) => s.status, 'status', AdminCustomersStatus.loading),
        isA<AdminCustomersState>()
            .having((s) => s.status, 'status', AdminCustomersStatus.ready)
            .having((s) => s.customers.length, 'customers.length', 2)
            .having((s) => s.total, 'total', 5)
            // The server handed back a bookmark, which is the whole of
            // hasMore: it is not derived from a count.
            .having((s) => s.hasMore, 'hasMore', true),
      ],
    );

    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'emits error with the repository message and code on Failure',
      build: () {
        when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
            (_) async => const Failure(AppError('Failed to load customers',
                code: kAdminCustomersLoadFailed)));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminCustomersState>()
            .having((s) => s.status, 'status', AdminCustomersStatus.loading),
        isA<AdminCustomersState>()
            .having((s) => s.status, 'status', AdminCustomersStatus.error)
            .having((s) => s.errorMessage, 'errorMessage',
                'Failed to load customers')
            .having((s) => s.errorCode, 'errorCode', kAdminCustomersLoadFailed),
      ],
    );
  });

  group('AdminCustomersCubit.loadMore', () {
    test('appends the page the bookmark names, then stops when told to',
        () async {
      when(() => repo.fetchCustomers(query: null, limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_sara, _omar],
                total: 3,
                nextCursor: _bookmark('profile-8'),
              )));
      when(() => repo.fetchCustomers(
            query: null,
            cursor: _bookmark('profile-8'),
            limit: 2,
          )).thenAnswer((_) async => Success<_Page>((
            customers: [_nour],
            total: null, // a continuation page carries no count
            nextCursor: null, // and this was the last one
          )));
      final cubit = buildCubit();

      await cubit.load();
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();

      expect(cubit.state.customers.map((c) => c.id),
          ['profile-9', 'profile-8', 'profile-7']);
      expect(cubit.state.isLoadingMore, isFalse);
      // The walk ends because the server said so, not because a running count
      // caught up with a total.
      expect(cubit.state.hasMore, isFalse,
          reason: 'no bookmark came back, so there is nothing after profile-7');
      // The "showing X of Y" line must survive a page that carried no count of
      // its own — otherwise it would read "showing 3 of 0".
      expect(cubit.state.total, 3,
          reason: 'the first page\'s total is the one that means anything');

      await cubit.loadMore();
      // Named against the bookmark, not `any(named: 'cursor')`: a first-page
      // load carries `cursor: null`, and matching on "some cursor" would count
      // the load as a page fetch and pass for the wrong reason.
      verify(() => repo.fetchCustomers(
            query: null,
            cursor: _bookmark('profile-8'),
            limit: 2,
          )).called(1);
    });

    test('does not fetch when the server has nothing more', () async {
      when(() => repo.fetchCustomers(query: null, limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_sara],
                total: 1,
                nextCursor: null,
              )));
      final cubit = buildCubit();

      await cubit.load();
      expect(cubit.state.hasMore, isFalse);

      await cubit.loadMore();

      // The load itself is one call, and it passes `cursor: null`, so a page
      // fetch would be indistinguishable from it by cursor alone — pin the
      // total number of calls instead. Two would mean `loadMore` ran despite
      // the server having said there was nothing more.
      verify(() => repo.fetchCustomers(
            query: any(named: 'query'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).called(1);
    });

    test('walks three pages by advancing the bookmark each time', () async {
      // Three pages on purpose. With only two, a bookmark that never advanced
      // still produces a plausible result set: page two would be fetched with
      // the *first* bookmark and `_nour` would simply arrive twice. Only the
      // third step makes the mistake visible as a duplicate row, which is the
      // exact failure keyset paging exists to prevent.
      when(() => repo.fetchCustomers(query: null, limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_sara, _omar],
                total: 5,
                nextCursor: _bookmark('profile-8'),
              )));
      when(() => repo.fetchCustomers(
            query: null,
            cursor: _bookmark('profile-8'),
            limit: 2,
          )).thenAnswer((_) async => Success<_Page>((
            customers: [_nour],
            total: null,
            nextCursor: _bookmark('profile-7'),
          )));
      when(() => repo.fetchCustomers(
            query: null,
            cursor: _bookmark('profile-7'),
            limit: 2,
          )).thenAnswer((_) async => Success<_Page>((
            customers: [_hoda],
            total: null,
            nextCursor: null,
          )));
      final cubit = buildCubit();

      await cubit.load();
      await cubit.loadMore();
      await cubit.loadMore();

      expect(cubit.state.customers.map((c) => c.id),
          ['profile-9', 'profile-8', 'profile-7', 'profile-6'],
          reason: 'no row may appear twice, and none may be stepped over');
      verify(() => repo.fetchCustomers(
            query: null,
            cursor: _bookmark('profile-7'),
            limit: 2,
          )).called(1);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.total, 5,
          reason: 'the total survives both continuation pages');
    });

    test('a failed page reports the error rather than a shorter list',
        () async {
      when(() => repo.fetchCustomers(query: null, limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_sara, _omar],
                total: 5,
                nextCursor: _bookmark('profile-8'),
              )));
      when(() => repo.fetchCustomers(
                query: null,
                cursor: _bookmark('profile-8'),
                limit: 2,
              ))
          .thenAnswer(
              (_) async => const Failure(AppError('page 2 unavailable')));
      final cubit = buildCubit();

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.status, AdminCustomersStatus.error);
      expect(cubit.state.errorMessage, 'page 2 unavailable');
      expect(cubit.state.isLoadingMore, isFalse);
    });
  });

  group('AdminCustomersCubit.search', () {
    test('queries the server and replaces the list with the matches', () async {
      when(() => repo.fetchCustomers(query: null, limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_sara, _omar],
                total: 5,
                nextCursor: _bookmark('profile-8'),
              )));
      when(() => repo.fetchCustomers(query: 'omar', limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_omar],
                total: 1,
                nextCursor: null,
              )));
      final cubit = buildCubit();
      await cubit.load();

      cubit.search('omar');
      await settle();

      expect(cubit.state.customers.single.id, 'profile-8');
      expect(cubit.state.total, 1,
          reason: 'total is the match count, not the size of the table');
      expect(cubit.state.hasMore, isFalse);
    });

    test('keystrokes within the debounce window collapse into one query',
        () async {
      when(() => repo.fetchCustomers(query: 's', limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_sara],
                total: 1,
                nextCursor: null,
              )));
      final cubit = AdminCustomersCubit(
        repository: repo,
        pageSize: 2,
        searchDebounce: const Duration(milliseconds: 30),
      );

      cubit.search('s');
      cubit.search('sa');
      cubit.search('s');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      verify(() => repo.fetchCustomers(query: 's', limit: 2)).called(1);
      verifyNever(() => repo.fetchCustomers(query: 'sa', limit: 2));
    });

    test('a slow response cannot overwrite a newer search', () async {
      final slow = Completer<Result<_Page>>();
      when(() => repo.fetchCustomers(query: 'slow', limit: 2))
          .thenAnswer((_) => slow.future);
      when(() => repo.fetchCustomers(query: 'fast', limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_omar],
                total: 1,
                nextCursor: null,
              )));
      final cubit = buildCubit();

      cubit.search('slow');
      await settle();
      cubit.search('fast');
      await settle();
      expect(cubit.state.customers.single.id, 'profile-8');

      // The superseded response lands last and must be discarded.
      slow.complete(Success<_Page>((
        customers: [_sara],
        total: 5,
        nextCursor: null,
      )));
      await settle();

      expect(cubit.state.customers.single.id, 'profile-8',
          reason: 'rows belonging to a superseded query must never be applied');
      expect(cubit.state.total, 1);
    });

    test('an in-flight page cannot append onto a newer search', () async {
      when(() => repo.fetchCustomers(query: null, limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_sara, _omar],
                total: 5,
                nextCursor: _bookmark('profile-8'),
              )));
      final pending = Completer<Result<_Page>>();
      when(() => repo.fetchCustomers(
            query: null,
            cursor: _bookmark('profile-8'),
            limit: 2,
          )).thenAnswer((_) => pending.future);
      when(() => repo.fetchCustomers(query: 'nour', limit: 2))
          .thenAnswer((_) async => Success<_Page>((
                customers: [_nour],
                total: 1,
                nextCursor: null,
              )));
      final cubit = buildCubit();
      await cubit.load();

      final more = cubit.loadMore();
      await settle();
      cubit.search('nour');
      await settle();
      expect(cubit.state.customers.single.id, 'profile-7');

      // Page 2 of the *previous* query resolves now: appending it would mix
      // two result sets together.
      pending.complete(Success<_Page>((
        customers: [_hoda],
        total: null,
        nextCursor: null,
      )));
      await more;
      await settle();

      expect(cubit.state.customers.single.id, 'profile-7',
          reason: 'the superseded page must not join the new search results');
      expect(cubit.state.total, 1,
          reason: 'nor may its missing count blank the search\'s total');
    });
  });

  group('AdminCustomersCubit.setMembershipTier', () {
    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'a confirmed write updates the row and keeps status ready',
      seed: () => AdminCustomersState(
        status: AdminCustomersStatus.ready,
        customers: [_sara, _omar],
        total: 2,
      ),
      build: () {
        when(() => repo.setMembershipTier('profile-9', 'premium'))
            .thenAnswer((_) async => const Success(null));
        return buildCubit();
      },
      act: (cubit) => cubit.setMembershipTier('profile-9', 'premium'),
      expect: () => [
        isA<AdminCustomersState>()
            .having((s) => s.customers.first.tier, 'tier', 'premium')
            .having((s) => s.status, 'status', AdminCustomersStatus.ready),
      ],
      verify: (cubit) {
        // Untouched neighbours stay untouched.
        expect(cubit.state.customers.last.tier, 'standard');
        verify(() => repo.setMembershipTier('profile-9', 'premium')).called(1);
      },
    );

    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'a failed write reports tierError and leaves the directory loaded',
      seed: () => AdminCustomersState(
        status: AdminCustomersStatus.ready,
        customers: [_sara, _omar],
        total: 2,
      ),
      build: () {
        when(() => repo.setMembershipTier('profile-9', 'premium')).thenAnswer(
            (_) async => const Failure(AppError('tier change rejected',
                code: kAdminMembershipUpdateFailed)));
        return buildCubit();
      },
      act: (cubit) => cubit.setMembershipTier('profile-9', 'premium'),
      expect: () => [
        isA<AdminCustomersState>()
            .having((s) => s.tierError, 'tierError', 'tier change rejected')
            .having((s) => s.tierErrorCode, 'tierErrorCode',
                kAdminMembershipUpdateFailed),
      ],
      verify: (cubit) {
        // The whole point of a separate channel: this page renders a
        // full-screen error view for AdminCustomersStatus.error, so a failed
        // write that set it would wipe the directory the admin was reading.
        expect(cubit.state.status, AdminCustomersStatus.ready,
            reason: 'a failed write must not trip the full-page error state');
        expect(cubit.state.customers, hasLength(2));
        expect(cubit.state.customers.first.tier, 'standard',
            reason: 'the failed write leaves the row on its previous tier');
      },
    );

    test('clearTierError empties the channel', () async {
      when(() => repo.setMembershipTier('profile-9', 'premium'))
          .thenAnswer((_) async => const Failure(AppError('nope')));
      final cubit = buildCubit();

      await cubit.setMembershipTier('profile-9', 'premium');
      expect(cubit.state.tierError, 'nope');

      cubit.clearTierError();
      expect(cubit.state.tierError, isNull);
    });
  });
}
