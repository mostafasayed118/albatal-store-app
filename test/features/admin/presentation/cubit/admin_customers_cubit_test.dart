import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_customers_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The customer directory cubit had no coverage at all before this file
/// (audit 2026-09-16, §14 follow-up), so these are the first pins on it —
/// including the one that matters most for the new tier control: a failed
/// write must never collapse the loaded directory into the error screen.
class _MockAdminRepository extends Mock implements AdminRepository {}

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

void main() {
  late _MockAdminRepository repo;

  setUp(() {
    repo = _MockAdminRepository();
  });

  group('AdminCustomersCubit.load', () {
    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'emits loading then ready, with the filtered view mirroring the list',
      build: () {
        when(() => repo.fetchCustomers())
            .thenAnswer((_) async => Success([_sara, _omar]));
        return AdminCustomersCubit(repository: repo);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminCustomersState>()
            .having((s) => s.status, 'status', AdminCustomersStatus.loading),
        isA<AdminCustomersState>()
            .having((s) => s.status, 'status', AdminCustomersStatus.ready)
            .having((s) => s.customers.length, 'customers.length', 2)
            .having((s) => s.visible.length, 'visible.length', 2),
      ],
    );

    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'emits error with the repository message on Failure',
      build: () {
        when(() => repo.fetchCustomers()).thenAnswer(
            (_) async => const Failure(AppError('Failed to load customers')));
        return AdminCustomersCubit(repository: repo);
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

  group('AdminCustomersCubit.filter', () {
    test('narrows on name and email, case-insensitively', () async {
      when(() => repo.fetchCustomers())
          .thenAnswer((_) async => Success([_sara, _omar]));
      final cubit = AdminCustomersCubit(repository: repo);
      await cubit.load();

      cubit.filter('sArA');
      expect(cubit.state.visible.single.id, 'profile-9');

      // The email column is what the schema leaves empty today, but the
      // filter has always matched it and that must not regress.
      cubit.filter('omar@batal');
      expect(cubit.state.visible.single.id, 'profile-8');

      // The unfiltered list survives a filter: search never mutates it.
      expect(cubit.state.customers, hasLength(2));
    });

    test('an empty query restores the whole directory', () async {
      when(() => repo.fetchCustomers())
          .thenAnswer((_) async => Success([_sara, _omar]));
      final cubit = AdminCustomersCubit(repository: repo);
      await cubit.load();

      cubit.filter('sara');
      expect(cubit.state.visible, hasLength(1));

      cubit.filter('   ');
      expect(cubit.state.visible, hasLength(2));
    });
  });

  group('AdminCustomersCubit.setMembershipTier', () {
    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'a confirmed write updates the row and keeps status ready',
      seed: () => AdminCustomersState(
        status: AdminCustomersStatus.ready,
        customers: [_sara, _omar],
        visible: [_sara, _omar],
      ),
      build: () {
        when(() => repo.setMembershipTier('profile-9', 'premium'))
            .thenAnswer((_) async => const Success(null));
        return AdminCustomersCubit(repository: repo);
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

    test('a write under an active search re-derives the filtered view',
        () async {
      // Regression guard: updating only `customers` would leave the visible
      // row showing the pre-write tier until the admin retyped the query.
      when(() => repo.fetchCustomers())
          .thenAnswer((_) async => Success([_sara, _omar]));
      when(() => repo.setMembershipTier('profile-9', 'premium'))
          .thenAnswer((_) async => const Success(null));
      final cubit = AdminCustomersCubit(repository: repo);
      await cubit.load();

      cubit.filter('sara');
      await cubit.setMembershipTier('profile-9', 'premium');

      expect(cubit.state.visible, hasLength(1),
          reason: 'the filter is still applied after the write');
      expect(cubit.state.visible.single.tier, 'premium',
          reason: 'the visible row carries the new tier, not the old one');
    });

    blocTest<AdminCustomersCubit, AdminCustomersState>(
      'a failed write reports tierError and leaves the directory loaded',
      seed: () => AdminCustomersState(
        status: AdminCustomersStatus.ready,
        customers: [_sara, _omar],
        visible: [_sara, _omar],
      ),
      build: () {
        when(() => repo.setMembershipTier('profile-9', 'premium')).thenAnswer(
            (_) async => const Failure(AppError('tier change rejected')));
        return AdminCustomersCubit(repository: repo);
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
        expect(cubit.state.visible, hasLength(2));
        expect(cubit.state.customers.first.tier, 'standard',
            reason: 'the failed write leaves the row on its previous tier');
      },
    );

    test('clearTierError empties the channel', () async {
      when(() => repo.setMembershipTier('profile-9', 'premium'))
          .thenAnswer((_) async => const Failure(AppError('nope')));
      final cubit = AdminCustomersCubit(repository: repo);

      await cubit.setMembershipTier('profile-9', 'premium');
      expect(cubit.state.tierError, 'nope');

      cubit.clearTierError();
      expect(cubit.state.tierError, isNull);
    });
  });
}
