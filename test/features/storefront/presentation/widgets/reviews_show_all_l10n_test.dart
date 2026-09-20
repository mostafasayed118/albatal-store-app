import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews_section.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit 2026-09-19 finding #4: the inline review list's Show-all button was a
/// hardcoded English literal (`Text('Show all ($remaining)')`), so an Arabic
/// shopper read English in the middle of a localized screen.
///
/// This pins the copy where a shopper actually meets it — the rendered button,
/// under the real localization delegate — rather than only the ARB value, since
/// a localized key that the widget forgets to call would still pass a key test.
/// Twelve reviews is deliberate: the inline list caps at 10, so exactly 2 stay
/// behind and the count in the label is non-trivial.
final class _FixedReviewsRepository implements ReviewsRepository {
  _FixedReviewsRepository(this.reviews);

  final List<ProductReview> reviews;

  @override
  Future<Result<List<ProductReview>>> fetchForProduct(String productId) async =>
      Success(reviews);

  @override
  Future<Result<ProductReview>> submit({
    required String productId,
    required int rating,
    required String text,
    List<int>? photoBytes,
  }) async =>
      throw UnimplementedError('not exercised by this test');
}

List<ProductReview> _reviews(int count) => List.generate(
      count,
      (i) => ProductReview(
        id: 'r$i',
        productId: 'p1',
        authorName: 'Shopper $i',
        rating: 5,
        text: 'Review body $i',
        createdAt: DateTime(2026, 1, 1),
      ),
    );

Future<void> _pumpSection(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewsSection(
            productId: 'p1',
            repository: _FixedReviewsRepository(_reviews(12)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('reviews Show-all label is localized (audit 2026-09-19 #4)', () {
    testWidgets('English renders the count with the English label',
        (tester) async {
      await _pumpSection(tester, const Locale('en'));

      expect(find.widgetWithText(TextButton, 'Show all (2)'), findsOneWidget);
    });

    testWidgets('Arabic renders Arabic, not the English literal',
        (tester) async {
      await _pumpSection(tester, const Locale('ar'));

      final ar = AppLocalizationsAr();
      expect(find.widgetWithText(TextButton, ar.showAllReviews(2)),
          findsOneWidget);
      // The regression this guards: English still on screen for an Arabic
      // shopper. Asserted as text, so any future literal reintroduction fails.
      expect(find.textContaining('Show all'), findsNothing);
    });

    testWidgets('a single hidden review drops the redundant count',
        (tester) async {
      // 11 reviews against the inline cap of 10 leaves exactly one behind, so
      // the plural's `=1` branch is the one on screen.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReviewsSection(
                productId: 'p1',
                repository: _FixedReviewsRepository(_reviews(11)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Show all'), findsOneWidget);
      expect(find.textContaining('Show all ('), findsNothing);
    });

    testWidgets('the button only appears when reviews are actually hidden',
        (tester) async {
      // Negative control: with exactly the inline cap of reviews there is
      // nothing behind the sheet, so a button would be a dead end.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReviewsSection(
                productId: 'p1',
                repository: _FixedReviewsRepository(_reviews(10)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Show all'), findsNothing);
    });
  });
}
