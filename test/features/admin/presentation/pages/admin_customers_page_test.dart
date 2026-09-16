import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_customers_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_customers_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// First widget coverage for the customer directory (feature-batch §14).
/// The page previously had none, so the tier control and the paging contract
/// arrive with the surface they change pinned end to end — including that a
/// failed write leaves the directory on screen instead of tripping the
/// full-page error state, and that the count line tells the admin how many
/// customers exist beyond the page they can see.
class _MockAdminRepository extends Mock implements AdminRepository {}

typedef _Page = ({List<AdminCustomer> customers, int total});

AdminCustomer _customer({
  String id = 'profile-9',
  String name = 'Sara Ali',
  String phone = '0100',
  String tier = 'standard',
}) =>
    AdminCustomer(
      id: id,
      name: name,
      phone: phone,
      tier: tier,
      isBlocked: false,
    );

void main() {
  late _MockAdminRepository repo;

  setUp(() {
    repo = _MockAdminRepository();
  });

  Widget harness({double textScale = 1.0, AdminCustomersCubit? cubit}) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            // Only the scale is overridden — size and insets stay the
            // view's. A bare `MediaQueryData(textScaler: ...)` would zero
            // the surface size, which is not what a scaled-up phone is.
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: AdminCustomersPage(repository: repo, cubit: cubit),
          ),
        ),
      );

  /// Opens the picker from the row's Change control.
  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
  }

  /// Picks [label] inside the dialog (a plain text find would also match
  /// the row's own tier label underneath).
  Future<void> pickInDialog(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(label),
    ));
    await tester.pump();
  }

  testWidgets('renders each customer with its tier and a Change control',
      (tester) async {
    when(() => repo.fetchCustomers(
            query: any(named: 'query'), limit: any(named: 'limit')))
        .thenAnswer(
            (_) async => Success<_Page>((customers: [_customer()], total: 1)));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Sara Ali'), findsOneWidget);
    // Tier is on the contact line; "Change" is the control, so the row
    // reads as a value plus an action rather than a captioned button.
    expect(find.text('0100 • Standard Member'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Showing 1 of 1'), findsOneWidget);
    // Everything is loaded, so there is no next page to offer.
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('states the server total and offers the next page',
      (tester) async {
    when(() =>
        repo.fetchCustomers(
            query: any(named: 'query'), limit: any(named: 'limit'))).thenAnswer(
        (_) async => Success<_Page>((customers: [_customer()], total: 120)));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // The old screen showed one row and said nothing about the other 119.
    expect(find.text('Showing 1 of 120'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);
  });

  testWidgets('Load more appends the next page and then stops offering it',
      (tester) async {
    final cubit = AdminCustomersCubit(
      repository: repo,
      pageSize: 1,
      searchDebounce: Duration.zero,
    );
    when(() => repo.fetchCustomers(query: null, limit: 1)).thenAnswer(
        (_) async => Success<_Page>((customers: [_customer()], total: 2)));
    when(() => repo.fetchCustomers(query: null, offset: 1, limit: 1))
        .thenAnswer((_) async => Success<_Page>((
              customers: [_customer(id: 'profile-8', name: 'Omar Nabil')],
              total: 2,
            )));

    await tester.pumpWidget(harness(cubit: cubit));
    await tester.pumpAndSettle();
    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('Omar Nabil'), findsNothing);

    await tester.tap(find.text('Load more'));
    // Pump (not settle) through the in-flight spinner, then let the page land.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Omar Nabil'), findsOneWidget);
    expect(find.text('Showing 2 of 2'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a search queries the server and reports no matches honestly',
      (tester) async {
    final cubit = AdminCustomersCubit(
      repository: repo,
      searchDebounce: Duration.zero,
    );
    when(() => repo.fetchCustomers(query: null, limit: 50)).thenAnswer(
        (_) async => Success<_Page>((customers: [_customer()], total: 1)));
    when(() => repo.fetchCustomers(query: 'zzz', limit: 50)).thenAnswer(
        (_) async => const Success<_Page>((customers: [], total: 0)));

    await tester.pumpWidget(harness(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(Duration.zero); // fire the debounce timer
    await tester.pump(); // let the response land

    verify(() => repo.fetchCustomers(query: 'zzz', limit: 50)).called(1);
    // The old screen rendered the bare word "Search" here, hint text and all.
    expect(find.text('No results found'), findsOneWidget);
    expect(find.text('Sara Ali'), findsNothing);
  });

  testWidgets('opens the picker seeded with the customer\'s current tier',
      (tester) async {
    when(() => repo.fetchCustomers(
            query: any(named: 'query'), limit: any(named: 'limit')))
        .thenAnswer((_) async => Success<_Page>((
              customers: [_customer(tier: 'premium')],
              total: 1,
            )));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openPicker(tester);

    expect(find.text('Change membership tier'), findsOneWidget);
    final group =
        tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
    expect(group.groupValue, 'premium',
        reason: 'the dialog must reflect the tier the customer is actually on');
  });

  testWidgets('a confirmed change writes the tier and then confirms it',
      (tester) async {
    when(() => repo.fetchCustomers(
            query: any(named: 'query'), limit: any(named: 'limit')))
        .thenAnswer(
            (_) async => Success<_Page>((customers: [_customer()], total: 1)));
    when(() => repo.setMembershipTier('profile-9', 'premium'))
        .thenAnswer((_) async => const Success(null));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openPicker(tester);
    await pickInDialog(tester, 'Premium Member');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verify(() => repo.setMembershipTier('profile-9', 'premium')).called(1);
    expect(find.text('Membership tier updated'), findsOneWidget);
    expect(find.text('0100 • Premium Member'), findsOneWidget,
        reason: 'the row reflects the tier the repository confirmed');
  });

  testWidgets('confirming the tier already in effect writes nothing',
      (tester) async {
    when(() => repo.fetchCustomers(
            query: any(named: 'query'), limit: any(named: 'limit')))
        .thenAnswer(
            (_) async => Success<_Page>((customers: [_customer()], total: 1)));
    when(() => repo.setMembershipTier(any(), any()))
        .thenAnswer((_) async => const Success(null));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openPicker(tester);
    // Confirm without touching the radios.
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.setMembershipTier(any(), any()));
    expect(find.text('Membership tier updated'), findsNothing,
        reason: 'an unchanged pick is not a write, so it earns no ack');
  });

  testWidgets(
      'a failed write floats the error and keeps the directory on screen',
      (tester) async {
    when(() => repo.fetchCustomers(
            query: any(named: 'query'), limit: any(named: 'limit')))
        .thenAnswer(
            (_) async => Success<_Page>((customers: [_customer()], total: 1)));
    when(() => repo.setMembershipTier('profile-9', 'premium')).thenAnswer(
        (_) async => const Failure(AppError('tier change rejected')));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openPicker(tester);
    await pickInDialog(tester, 'Premium Member');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('tier change rejected'), findsOneWidget);
    expect(find.text('Membership tier updated'), findsNothing);
    // The regression this guards: routing the failure through `status`
    // would render the full-screen FeedbackView error and erase the
    // directory the admin was working in.
    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('0100 • Standard Member'), findsOneWidget,
        reason: 'the row keeps the tier the write failed to change');
  });

  testWidgets('the row and its control survive a 1.4 text scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    when(() => repo.fetchCustomers(
            query: any(named: 'query'), limit: any(named: 'limit')))
        .thenAnswer((_) async => Success<_Page>((
              customers: [
                _customer(),
                _customer(id: 'profile-8', name: 'Omar Nabil', tier: 'premium'),
              ],
              total: 2,
            )));

    await tester.pumpWidget(harness(textScale: 1.4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'a trailing control in a ListTile is where large text breaks');
    expect(find.text('Change'), findsNWidgets(2));
    expect(find.textContaining('Premium Member'), findsOneWidget);
    expect(find.text('Showing 2 of 2'), findsOneWidget);
  });
}
