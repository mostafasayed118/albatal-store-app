import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_coupon.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_coupons_port.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_coupons_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/coupons/admin_coupons_view.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCouponsRepository extends Mock implements AdminCouponsPort {}

const _eid =
    AdminCoupon(id: 'c1', code: 'EID25', discountMinor: 1000, active: true);
const _save =
    AdminCoupon(id: 'c2', code: 'SAVE', discountMinor: 250, active: false);

Widget _harness(AdminCouponsCubit cubit) =>
    BlocProvider<AdminCouponsCubit>.value(
      value: cubit,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminCouponsView(),
      ),
    );

Future<void> _openCreateSheet(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add coupon'));
  await tester.pump();
}

/// Submits a valid form. The view disposes its controllers as soon as the
/// sheet pops, before the exit animation ends — rebuilding that exiting
/// sheet would trip a disposed-controller assertion (lib defect, not the
/// test target). Replacing the tree drops the route without rebuilding it.
Future<void> _submitAndDismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add coupon'));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump();
}

void main() {
  late _MockCouponsRepository repository;
  late AdminCouponsCubit cubit;

  setUp(() {
    repository = _MockCouponsRepository();
    cubit = AdminCouponsCubit(repository: repository);
    addTearDown(cubit.close);
    when(() => repository.fetchCoupons())
        .thenAnswer((_) async => const Success([_eid, _save]));
  });

  testWidgets('renders the shared loading state while the read is in flight',
      (tester) async {
    final pending = Completer<Result<List<AdminCoupon>>>();
    when(() => repository.fetchCoupons()).thenAnswer((_) => pending.future);
    unawaited(cubit.load());

    await tester.pumpWidget(_harness(cubit));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const Success([]));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error body offers a retry that reloads the coupon list',
      (tester) async {
    when(() => repository.fetchCoupons())
        .thenAnswer((_) async => const Failure(AppError('offline')));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);

    when(() => repository.fetchCoupons())
        .thenAnswer((_) async => const Success([_eid]));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    verify(() => repository.fetchCoupons()).called(2);
    expect(find.text('EID25'), findsOneWidget);
    expect(find.text('offline'), findsNothing);
  });

  testWidgets('empty list renders the empty state without a duplicate CTA',
      (tester) async {
    when(() => repository.fetchCoupons())
        .thenAnswer((_) async => const Success([]));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    final empty = tester.widget<FeedbackView>(find.byType(FeedbackView));
    expect(empty.type, FeedbackViewType.empty);
    expect(find.byType(AppButton), findsNothing,
        reason: 'the create FAB owns the action');
  });

  testWidgets('lists coupons with formatter-backed prices and live toggles',
      (tester) async {
    when(() => repository.setCouponActive('c1', false))
        .thenAnswer((_) async => const Success(null));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    expect(find.text('EID25'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
    expect(find.text('EGP 10.00'), findsOneWidget);
    expect(find.text('EGP 2.50'), findsOneWidget);
    expect(
      tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value),
      [true, false],
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    verify(() => repository.setCouponActive('c1', false)).called(1);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
  });

  testWidgets('toggle failure replaces the list with the error surface',
      (tester) async {
    when(() => repository.setCouponActive('c1', false))
        .thenAnswer((_) async => const Failure(AppError('toggle rejected')));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.text('toggle rejected'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('create sheet rejects empty and non-positive input, then submits',
      (tester) async {
    when(() => repository.createCoupon(
          code: any(named: 'code'),
          discountMinor: any(named: 'discountMinor'),
          description: any(named: 'description'),
        )).thenAnswer((_) async => const Success(_eid));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));
    await _openCreateSheet(tester);

    await _tapSubmit(tester);
    verifyNever(() => repository.createCoupon(
          code: any(named: 'code'),
          discountMinor: any(named: 'discountMinor'),
          description: any(named: 'description'),
        ));

    await tester.enterText(find.byType(TextField).first, 'save10');
    await tester.enterText(find.byType(TextField).last, '0');
    await _tapSubmit(tester);
    verifyNever(() => repository.createCoupon(
          code: any(named: 'code'),
          discountMinor: any(named: 'discountMinor'),
          description: any(named: 'description'),
        ));

    await tester.enterText(find.byType(TextField).last, 'invalid');
    await _tapSubmit(tester);
    verifyNever(() => repository.createCoupon(
          code: any(named: 'code'),
          discountMinor: any(named: 'discountMinor'),
          description: any(named: 'description'),
        ));

    await tester.enterText(find.byType(TextField).last, '25');
    await _submitAndDismiss(tester);

    verify(() => repository.createCoupon(
          code: 'save10',
          discountMinor: 2500,
          description: null,
        )).called(1);
    verify(() => repository.fetchCoupons()).called(2);
  });

  testWidgets('create failure surfaces on the list screen', (tester) async {
    when(() => repository.createCoupon(
          code: any(named: 'code'),
          discountMinor: any(named: 'discountMinor'),
          description: any(named: 'description'),
        )).thenAnswer((_) async => const Failure(AppError('coupon rejected')));
    await cubit.load();
    await tester.pumpWidget(_harness(cubit));
    await _openCreateSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'SAVE');
    await tester.enterText(find.byType(TextField).last, '10');
    await _submitAndDismiss(tester);

    expect(cubit.state.status, AdminCouponsStatus.error);
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('coupon rejected'), findsOneWidget);
    expect(find.byType(FeedbackView), findsOneWidget);
  });
}
