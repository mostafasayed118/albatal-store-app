import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/review_mapper.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_reviews_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// Client-side submit guards (audit P5): empty and over-long review text
/// fail fast with the invalid code before any network call.
void main() {
  group('SupabaseReviewsRepository.submit guards', () {
    test('blank text fails with the invalid code, no network call', () async {
      final client = _MockSupabaseClient();
      final repo = SupabaseReviewsRepository(client: client);

      final result = await repo.submit(productId: 'p1', rating: 5, text: '   ');

      expect(result, isA<Failure>());
      final failure = result as Failure;
      expect(failure.error.code, kReviewInvalid);
      verifyNever(() => client.from(any()));
    });

    test('over-long text fails with the invalid code, no network call',
        () async {
      final client = _MockSupabaseClient();
      final repo = SupabaseReviewsRepository(client: client);
      final long = List.filled(maxReviewTextLength + 1, 'a').join();

      final result = await repo.submit(productId: 'p1', rating: 5, text: long);

      expect(result, isA<Failure>());
      final failure = result as Failure;
      expect(failure.error.code, kReviewInvalid);
      verifyNever(() => client.from(any()));
    });

    test('out-of-range rating keeps its invalid code', () async {
      final client = _MockSupabaseClient();
      final repo = SupabaseReviewsRepository(client: client);

      final result = await repo.submit(productId: 'p1', rating: 0, text: 'ok');

      expect(result, isA<Failure>());
      expect((result as Failure).error.code, kReviewInvalid);
      verifyNever(() => client.from(any()));
    });
  });
}
