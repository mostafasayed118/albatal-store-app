import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
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

typedef _Page = ({List<AdminCustomer> customers, int total});

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
        when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
            (_) async => Success<_Page>((customers: [_sara, _omar], total: 5)));
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
            .having((s) => s.hasMore, 'hasMore', true),
      ],
    );

    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'emits error with the repository message on Failure',
      build: () {
        when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
            (_) async => const Failure(AppError('Failed to load customers')));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminCustomersState>()
            .having((s) => s.status, 'status', AdminCustomersStatus.loading),
        isA<AdminCustomersState>()
            .having((s) => s.status, 'status', AdminCustomersStatus.error)
            .having((s) => s.errorMessage, 'errorMessage',
                'Failed to load customers'),
      ],
    );
  });

  group('AdminCustomersCubit.loadMore', () {
    test('appends the next page at the next offset and then stops', () async {
      when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_sara, _omar], total: 3)));
      when(() => repo.fetchCustomers(query: null, offset: 2, limit: 2))
          .thenAnswer(
              (_) async => Success<_Page>((customers: [_nour], total: 3)));
      final cubit = buildCubit();

      await cubit.load();
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();

      expect(cubit.state.customers.map((c) => c.id),
          ['profile-9', 'profile-8', 'profile-7']);
      expect(cubit.state.isLoadingMore, isFalse);
      // Two rows asked for, three rows known: the offset advanced by the page
      // size, not by what came back, so the extra row is not re-requested.
      expect(cubit.state.hasMore, isFalse,
          reason: 'offset 4 has reached the server total of 3');

      await cubit.loadMore();
      verifyNever(() => repo.fetchCustomers(query: null, offset: 4, limit: 2));
    });

    test('does not fetch when the server has nothing more', () async {
      when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_sara], total: 1)));
      final cubit = buildCubit();

      await cubit.load();
      expect(cubit.state.hasMore, isFalse);

      await cubit.loadMore();

      // Specific to the next offset: a looser pattern would also match the
      // first-page load and pass for the wrong reason.
      verifyNever(() => repo.fetchCustomers(query: null, offset: 2, limit: 2));
    });

    test('a short page still advances by the page size, not by rows loaded',
        () async {
      // The repository skips rows it cannot decode, so a page can come back
      // short while the server holds more. Paging off the loaded count would
      // re-request rows that were already consumed.
      //
      // Three pages on purpose: after only two, "consumed" and "displayed"
      // still agree, so the mistake is invisible. Page two returns a single
      // row for a two-row request, which is where they diverge — page three
      // must therefore ask for offset 4 (two consumed, then two more), not 3.
      when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_sara, _omar], total: 5)));
      when(() => repo.fetchCustomers(query: null, offset: 2, limit: 2))
          .thenAnswer(
              (_) async => Success<_Page>((customers: [_nour], total: 5)));
      when(() => repo.fetchCustomers(query: null, offset: 4, limit: 2))
          .thenAnswer(
              (_) async => Success<_Page>((customers: [_hoda], total: 5)));
      final cubit = buildCubit();

      await cubit.load();
      await cubit.loadMore();
      await cubit.loadMore();

      verify(() => repo.fetchCustomers(query: null, offset: 4, limit: 2))
          .called(1);
      expect(cubit.state.customers.map((c) => c.id),
          ['profile-9', 'profile-8', 'profile-7', 'profile-6']);
      expect(cubit.state.hasMore, isFalse,
          reason: 'offset 6 is past the server total of 5');
    });

    test('a failed page reports the error rather than a shorter list',
        () async {
      when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_sara, _omar], total: 5)));
      when(() => repo.fetchCustomers(query: null, offset: 2, limit: 2))
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
      when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_sara, _omar], total: 5)));
      when(() => repo.fetchCustomers(query: 'omar', limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_omar], total: 1)));
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
      when(() => repo.fetchCustomers(query: 's', limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_sara], total: 1)));
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
      when(() => repo.fetchCustomers(query: 'fast', limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_omar], total: 1)));
      final cubit = buildCubit();

      cubit.search('slow');
      await settle();
      cubit.search('fast');
      await settle();
      expect(cubit.state.customers.single.id, 'profile-8');

      // The superseded response lands last and must be discarded.
      slow.complete(Success<_Page>((customers: [_sara], total: 5)));
      await settle();

      expect(cubit.state.customers.single.id, 'profile-8',
          reason: 'rows belonging to a superseded query must never be applied');
      expect(cubit.state.total, 1);
    });

    test('an in-flight page cannot append onto a newer search', () async {
      when(() => repo.fetchCustomers(query: null, limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_sara, _omar], total: 5)));
      final pending = Completer<Result<_Page>>();
      when(() => repo.fetchCustomers(query: null, offset: 2, limit: 2))
          .thenAnswer((_) => pending.future);
      when(() => repo.fetchCustomers(query: 'nour', limit: 2)).thenAnswer(
          (_) async => Success<_Page>((customers: [_nour], total: 1)));
      final cubit = buildCubit();
      await cubit.load();

      final more = cubit.loadMore();
      await settle();
      cubit.search('nour');
      await settle();
      expect(cubit.state.customers.single.id, 'profile-7');

      // Page 2 of the *previous* query resolves now: appending it would mix
      // two result sets together.
      pending.complete(Success<_Page>((customers: [_hoda], total: 5)));
      await more;
      await settle();

      expect(cubit.state.customers.single.id, 'profile-7',
          reason: 'the superseded page must not join the new search results');
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
            (_) async => const Failure(AppError('tier change rejected')));
        return buildCubit();
      },
      act: (cubit) => cubit.setMembershipTier('profile-9', 'premium'),
      expect: () => [
        isA<AdminCustomersState>()
            .having((s) => s.tierError, 'tierError', 'tier change rejected'),
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
