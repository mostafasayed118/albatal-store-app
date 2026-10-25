import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_reviews_port.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_reviews_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockReviewsRepository extends Mock implements AdminReviewsPort {}

void main() {
  late _MockReviewsRepository repository;

  setUp(() {
    repository = _MockReviewsRepository();
  });

  test('a double tap sends one write for the same review', () async {
    final write = Completer<Result<void>>();
    when(() => repository.setReviewStatus('r1', 'approved'))
        .thenAnswer((_) => write.future);
    final cubit = AdminReviewsCubit(repository: repository);
    addTearDown(cubit.close);

    final first = cubit.moderate('r1', approve: true);
    final second = cubit.moderate('r1', approve: true);

    write.complete(const Success(null));
    await Future.wait([first, second]);

    verify(() => repository.setReviewStatus('r1', 'approved')).called(1);
  });

  test('different rows are not blocked by another row being in flight',
      () async {
    final firstWrite = Completer<Result<void>>();
    when(() => repository.setReviewStatus('r1', 'approved'))
        .thenAnswer((_) => firstWrite.future);
    when(() => repository.setReviewStatus('r2', 'rejected'))
        .thenAnswer((_) async => const Success(null));
    final cubit = AdminReviewsCubit(repository: repository);
    addTearDown(cubit.close);

    final first = cubit.moderate('r1', approve: true);
    await cubit.moderate('r2', approve: false);

    verify(() => repository.setReviewStatus('r2', 'rejected')).called(1);

    firstWrite.complete(const Success(null));
    await first;
  });

  test('a failed write releases the guard so the row can be retried', () async {
    var calls = 0;
    when(() => repository.setReviewStatus('r1', 'approved'))
        .thenAnswer((_) async {
      calls++;
      return calls == 1
          ? const Failure(AppError('first attempt failed'))
          : const Success(null);
    });
    when(() => repository.fetchPendingReviews()).thenAnswer(
      (_) async => const Success(<PendingReview>[
        (id: 'r1', product: 'Royal Silk', text: 'Lovely', rating: 5),
      ]),
    );
    final cubit = AdminReviewsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.moderate('r1', approve: true);
    await cubit.moderate('r1', approve: true);

    expect(calls, 2, reason: 'the retry is not treated as a duplicate');
    expect(cubit.state.pending, isEmpty,
        reason: 'the successful retry removes the row');
  });
}
