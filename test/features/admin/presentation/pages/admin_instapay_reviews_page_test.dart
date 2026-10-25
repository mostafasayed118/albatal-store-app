import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/instapay_proof.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_instapay_port.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_instapay_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_instapay_reviews_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:al_batal_elite/shared/utils/app_date_formats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInstapayPort extends Mock implements AdminInstapayPort {}

InstapayProof _proof(
  String id, {
  String customer = 'Mona Hassan',
  String? reference = 'TRX-9911',
  String storagePath = '',
}) =>
    InstapayProof(
      proofId: id,
      paymentId: 'pay-$id',
      orderId: '1234567890',
      total: const Money(150000),
      customerName: customer,
      reference: reference,
      storagePath: storagePath,
      createdAt: DateTime.utc(2026, 10, 25, 12),
    );

Widget _harness(AdminInstapayCubit cubit, AdminInstapayPort port) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminInstapayReviewsPage(cubit: cubit, repository: port),
    );

// The page's BlocProvider owns the injected cubit and closes it when the tree
// is disposed. Tests must NOT addTearDown(cubit.close): a second close while
// the provider still holds a live subscription deadlocks the test isolate
// (verified while probing this surface), and the provider's close is enough.

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late _MockInstapayPort port;

  setUp(() {
    port = _MockInstapayPort();
  });

  testWidgets('renders the pending queue with payer, order, total and actions',
      (tester) async {
    when(() => port.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    expect(find.text('Mona Hassan'), findsOneWidget);
    expect(find.text('Order #12345678'), findsOneWidget);
    expect(find.text('1,500 EGP'), findsOneWidget);
    expect(find.text('TRX-9911'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(
      find.text(
        AppDateFormats.dayMonthYearTime('en')
            .format(DateTime.utc(2026, 10, 25, 12)),
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
  });

  testWidgets('a proof with a stored file asks for a signed URL',
      (tester) async {
    when(() => port.listPendingProofs()).thenAnswer(
        (_) async => Success([_proof('p1', storagePath: 'proofs/p1.jpg')]));
    when(() => port.signedProofUrl('proofs/p1.jpg'))
        .thenAnswer((_) async => const Success('https://signed.example/p1'));
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    verify(() => port.signedProofUrl('proofs/p1.jpg')).called(1);
  });

  testWidgets('a proof without a file shows the missing-proof placeholder',
      (tester) async {
    when(() => port.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    expect(
      find.byTooltip('This payment has no transfer proof attached.'),
      findsOneWidget,
    );
    verifyNever(() => port.signedProofUrl(any()));
  });

  testWidgets('an empty queue renders the empty state', (tester) async {
    when(() => port.listPendingProofs())
        .thenAnswer((_) async => const Success([]));
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    final view = tester.widget<FeedbackView>(find.byType(FeedbackView));
    expect(view.type, FeedbackViewType.empty);
    expect(
        find.text('No InstaPay payments waiting for review'), findsOneWidget);
  });

  testWidgets('a failed load localizes the failure and retries',
      (tester) async {
    when(() => port.listPendingProofs()).thenAnswer(
      (_) async => const Failure(
        AppError('diagnosis only', code: kAdminInstapayLoadFailed),
      ),
    );
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    expect(find.text('Could not load InstaPay payments'), findsWidgets);
    expect(find.text('diagnosis only'), findsNothing,
        reason: 'feature-coded failures never render the English diagnosis');

    when(() => port.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    await tester.tap(find.text('Retry'));
    await _settle(tester);

    verify(() => port.listPendingProofs()).called(2);
    expect(find.text('Mona Hassan'), findsOneWidget);
    expect(find.text('Could not load InstaPay payments'), findsNothing);
  });

  testWidgets('confirming approve calls the review and removes the row',
      (tester) async {
    when(() => port.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    when(() => port.reviewProof('p1', approve: true, note: any(named: 'note')))
        .thenAnswer((_) async => const Success(null));
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await _settle(tester);
    expect(
      find.text('Approve this payment and mark the order as paid?'),
      findsOneWidget,
    );

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Approve'),
    ));
    await _settle(tester);

    verify(() =>
            port.reviewProof('p1', approve: true, note: any(named: 'note')))
        .called(1);
    expect(find.text('Mona Hassan'), findsNothing);
    expect(find.text('Payment approved'), findsOneWidget);
  });

  testWidgets('reject sends the reviewer note', (tester) async {
    when(() => port.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    when(() => port.reviewProof('p1', approve: false, note: any(named: 'note')))
        .thenAnswer((_) async => const Success(null));
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'amount mismatch');

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Reject'),
    ));
    await _settle(tester);

    verify(() =>
            port.reviewProof('p1', approve: false, note: 'amount mismatch'))
        .called(1);
    expect(find.text('Mona Hassan'), findsNothing);
    expect(find.text('Payment proof rejected'), findsOneWidget);
  });

  testWidgets('a rejected write keeps the row and shows the retry copy',
      (tester) async {
    when(() => port.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    when(() => port.reviewProof('p1', approve: true, note: any(named: 'note')))
        .thenAnswer((_) async => const Failure(
              AppError('diagnosis only', code: kAdminInstapayReviewFailed),
            ));
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await _settle(tester);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Approve'),
    ));
    await _settle(tester);

    expect(find.text('Mona Hassan'), findsOneWidget,
        reason: 'a failed review leaves the row retryable');
    expect(find.text('Could not save the review. Please try again.'),
        findsOneWidget);
  });

  testWidgets('the in-flight row swaps its actions for a spinner',
      (tester) async {
    when(() => port.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    final write = Completer<Result<void>>();
    when(() => port.reviewProof('p1', approve: true, note: any(named: 'note')))
        .thenAnswer((_) => write.future);
    final cubit = AdminInstapayCubit(repository: port);

    await tester.pumpWidget(_harness(cubit, port));
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await _settle(tester);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Approve'),
    ));
    // Let the dialog finish its exit transition so its own Approve button is
    // gone from the tree, otherwise the assertion below matches it.
    await _settle(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing,
        reason: 'the row cannot be reviewed twice while in flight');

    write.complete(const Success(null));
    await _settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Mona Hassan'), findsNothing);
  });
}
