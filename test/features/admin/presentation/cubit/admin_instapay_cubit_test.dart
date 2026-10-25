import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/instapay_proof.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_instapay_port.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_instapay_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInstapayPort extends Mock implements AdminInstapayPort {}

InstapayProof _proof(String id) => InstapayProof(
      proofId: id,
      paymentId: 'pay-$id',
      orderId: 'order-$id',
      total: const Money(150000),
      customerName: 'Customer $id',
      storagePath: 'proofs/$id.jpg',
      createdAt: DateTime.utc(2026, 10, 25, 12),
    );

void main() {
  late _MockInstapayPort repository;

  setUp(() {
    repository = _MockInstapayPort();
  });

  test('load publishes the pending queue and clears a previous error',
      () async {
    when(() => repository.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1'), _proof('p2')]));
    final cubit = AdminInstapayCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminInstapayStatus.ready);
    expect(cubit.state.proofs.map((p) => p.proofId), ['p1', 'p2']);
    expect(cubit.state.errorCode, isNull);
  });

  test('a failed load exposes the coded error', () async {
    when(() => repository.listPendingProofs()).thenAnswer(
      (_) async => const Failure(
        AppError('diagnosis only', code: kAdminInstapayLoadFailed),
      ),
    );
    final cubit = AdminInstapayCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminInstapayStatus.error);
    expect(cubit.state.errorCode, kAdminInstapayLoadFailed);
    expect(cubit.state.proofs, isEmpty);

    // A retry that succeeds must not keep the stale error around.
    when(() => repository.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    await cubit.load();

    expect(cubit.state.status, AdminInstapayStatus.ready);
    expect(cubit.state.errorCode, isNull);
  });

  test('approve removes the row and emits a confirmation action', () async {
    when(() => repository.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1'), _proof('p2')]));
    when(() => repository.reviewProof('p1',
        approve: true,
        note: any(named: 'note'))).thenAnswer((_) async => const Success(null));
    final cubit = AdminInstapayCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.approve('p1');

    expect(cubit.state.proofs.map((p) => p.proofId), ['p2']);
    expect(cubit.state.reviewingIds, isEmpty);
    final action = cubit.state.lastAction;
    expect(action, isNotNull);
    expect(action!.approve, isTrue);
    expect(action.failed, isFalse);
    expect(action.proofId, 'p1');
  });

  test('reject forwards the trimmed note and removes the row', () async {
    when(() => repository.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    when(() => repository.reviewProof('p1',
        approve: false,
        note: any(named: 'note'))).thenAnswer((_) async => const Success(null));
    final cubit = AdminInstapayCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.reject('p1', note: 'amount mismatch');

    verify(() => repository.reviewProof('p1',
        approve: false, note: 'amount mismatch')).called(1);
    expect(cubit.state.proofs, isEmpty);
    expect(cubit.state.lastAction?.approve, isFalse);
  });

  test('a failed review keeps the row and the queue loaded', () async {
    when(() => repository.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    when(() => repository.reviewProof('p1',
            approve: true, note: any(named: 'note')))
        .thenAnswer((_) async => const Failure(
              AppError('diagnosis only', code: kAdminInstapayReviewFailed),
            ));
    final cubit = AdminInstapayCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.approve('p1');

    expect(cubit.state.status, AdminInstapayStatus.ready,
        reason: 'the queue is still rendered, not replaced by an error page');
    expect(cubit.state.proofs.map((p) => p.proofId), ['p1'],
        reason: 'a failure must leave the row retryable');
    expect(cubit.state.errorCode, kAdminInstapayReviewFailed);
    expect(cubit.state.reviewingIds, isEmpty);
    expect(cubit.state.lastAction?.failed, isTrue);
  });

  test('a double tap sends one review for the same row', () async {
    final write = Completer<Result<void>>();
    when(() => repository.reviewProof('p1',
        approve: true,
        note: any(named: 'note'))).thenAnswer((_) => write.future);
    final cubit = AdminInstapayCubit(repository: repository);
    addTearDown(cubit.close);

    final first = cubit.approve('p1');
    final second = cubit.approve('p1');

    expect(cubit.state.isReviewing('p1'), isTrue,
        reason: 'the row shows a spinner while the write is in flight');
    write.complete(const Success(null));
    await Future.wait([first, second]);

    verify(() => repository.reviewProof('p1',
        approve: true, note: any(named: 'note'))).called(1);
    expect(cubit.state.isReviewing('p1'), isFalse);
  });

  test('a stale load cannot overwrite a newer queue', () async {
    final first = Completer<Result<List<InstapayProof>>>();
    final second = Completer<Result<List<InstapayProof>>>();
    var calls = 0;
    when(() => repository.listPendingProofs()).thenAnswer((_) {
      calls++;
      return calls == 1 ? first.future : second.future;
    });
    final cubit = AdminInstapayCubit(repository: repository);
    addTearDown(cubit.close);

    final stale = cubit.load();
    final fresh = cubit.load();

    second.complete(Success([_proof('fresh')]));
    await fresh;
    first.complete(Success([_proof('stale')]));
    await stale;

    expect(cubit.state.proofs.map((p) => p.proofId), ['fresh'],
        reason: 'the first response landed after the second and must drop');
  });

  test('never emits after close', () async {
    final list = Completer<Result<List<InstapayProof>>>();
    when(() => repository.listPendingProofs()).thenAnswer((_) => list.future);
    final cubit = AdminInstapayCubit(repository: repository);

    final pending = cubit.load();
    await cubit.close();
    list.complete(Success([_proof('late')]));

    await expectLater(pending, completes);
    expect(cubit.isClosed, isTrue);
  });

  test('a review completing after close does not emit', () async {
    when(() => repository.listPendingProofs())
        .thenAnswer((_) async => Success([_proof('p1')]));
    final write = Completer<Result<void>>();
    when(() => repository.reviewProof('p1',
        approve: true,
        note: any(named: 'note'))).thenAnswer((_) => write.future);
    final cubit = AdminInstapayCubit(repository: repository);
    await cubit.load();

    final pending = cubit.approve('p1');
    await cubit.close();
    write.complete(const Success(null));

    await expectLater(pending, completes);
    expect(cubit.isClosed, isTrue);
  });
}
