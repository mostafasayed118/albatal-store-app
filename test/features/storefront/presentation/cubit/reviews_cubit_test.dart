import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/review_mapper.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reviews_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockReviewsRepo extends Mock implements ReviewsRepository {}

Map<String, dynamic> _row() => {
      'id': 'rev-1',
      'product_id': 'p1',
      'rating': 4,
      'text': 'Lovely drape',
      'created_at': '2025-09-09T00:00:00.000Z',
      'author_name': 'Nour',
      'photo_url': 'https://example.test/photo.jpg',
    };

void main() {
  group('reviewFromRow (§9)', () {
    test('maps a valid row', () {
      final review = reviewFromRow(_row());
      expect(review, isNotNull);
      expect(review!.id, 'rev-1');
      expect(review.rating, 4);
      expect(review.authorName, 'Nour');
      expect(review.photoUrl, isNotNull);
      expect(review.createdAt, DateTime.utc(2025, 9, 9));
    });

    test('fails closed on out-of-range ratings', () {
      expect(reviewFromRow({..._row(), 'rating': 0}), isNull);
      expect(reviewFromRow({..._row(), 'rating': 6}), isNull);
    });

    test('fails closed on missing ids', () {
      expect(reviewFromRow({..._row(), 'id': ''}), isNull);
      expect(reviewFromRow({..._row(), 'product_id': ''}), isNull);
    });

    test('fails closed on a missing timestamp', () {
      final row = _row()..remove('created_at');
      expect(reviewFromRow(row), isNull);
    });
  });

  group('ReviewsCubit (§9)', () {
    test('unavailable without a repository (pre-DI / no 050 yet)', () async {
      final cubit = ReviewsCubit();
      await cubit.load('p1');
      expect(cubit.state.status, ReviewsStatus.unavailable);
      await cubit.close();
    });

    test('loads approved reviews for a product', () async {
      final repo = _MockReviewsRepo();
      final review = reviewFromRow(_row())!;
      when(() => repo.fetchForProduct('p1'))
          .thenAnswer((_) async => Success([review]));
      final cubit = ReviewsCubit(repository: repo);

      await cubit.load('p1');
      expect(cubit.state.status, ReviewsStatus.ready);
      expect(cubit.state.reviews, [review]);
      await cubit.close();
    });

    test('backend absent degrades to unavailable status', () async {
      final repo = _MockReviewsRepo();
      when(() => repo.fetchForProduct('p1'))
          .thenAnswer((_) async => const Failure(AppError(kReviewUnavailable)));
      final cubit = ReviewsCubit(repository: repo);

      await cubit.load('p1');
      expect(cubit.state.status, ReviewsStatus.unavailable);
      await cubit.close();
    });

    test('submit surfaces buy-to-review requirement as a message', () async {
      final repo = _MockReviewsRepo();
      when(() => repo.fetchForProduct('p1'))
          .thenAnswer((_) async => const Success(<ProductReview>[]));
      when(() => repo.submit(
                productId: 'p1',
                rating: any(named: 'rating'),
                text: any(named: 'text'),
                photoBytes: any(named: 'photoBytes'),
              ))
          .thenAnswer((_) async => const Failure(AppError(kReviewBuyRequired)));
      final cubit = ReviewsCubit(repository: repo);
      await cubit.load('p1');

      await cubit.submit(rating: 5, text: 'great');
      expect(cubit.state.submitMessage, kReviewBuyRequired);
      expect(cubit.state.submitting, isFalse);
      await cubit.close();
    });

    test('load classifies on error.code, not the message (audit)', () async {
      final repo = _MockReviewsRepo();
      // A coded failure with unrelated prose still degrades to unavailable.
      when(() => repo.fetchForProduct('p1')).thenAnswer((_) async =>
          const Failure(AppError('boom', code: kReviewUnavailable)));
      final cubit = ReviewsCubit(repository: repo);

      await cubit.load('p1');
      expect(cubit.state.status, ReviewsStatus.unavailable);
      await cubit.close();
    });

    test('load treats an uncoded failure as a generic error (audit)', () async {
      final repo = _MockReviewsRepo();
      when(() => repo.fetchForProduct('p1'))
          .thenAnswer((_) async => const Failure(AppError('boom')));
      final cubit = ReviewsCubit(repository: repo);

      await cubit.load('p1');
      expect(cubit.state.status, ReviewsStatus.error);
      await cubit.close();
    });

    test('submit carries the failure code, not prose (audit)', () async {
      final repo = _MockReviewsRepo();
      when(() => repo.fetchForProduct('p1'))
          .thenAnswer((_) async => const Success(<ProductReview>[]));
      when(() => repo.submit(
                productId: 'p1',
                rating: any(named: 'rating'),
                text: any(named: 'text'),
                photoBytes: any(named: 'photoBytes'),
              ))
          .thenAnswer((_) async =>
              const Failure(AppError('boom', code: kReviewBuyRequired)));
      final cubit = ReviewsCubit(repository: repo);
      await cubit.load('p1');

      await cubit.submit(rating: 5, text: 'great');
      expect(cubit.state.submitMessage, kReviewBuyRequired);
      await cubit.close();
    });
  });
}
