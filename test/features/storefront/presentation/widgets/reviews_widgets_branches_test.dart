import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reviews_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews/review_submit_sheet.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews/review_tile.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews/reviews_inline_list.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews/reviews_view.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Reviews implements ReviewsRepository {
  _Reviews(this.reviews);

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
      throw UnimplementedError();
}

List<ProductReview> _reviews(int count) => [
      for (var i = 0; i < count; i++)
        ProductReview(
          id: 'r$i',
          productId: 'p1',
          authorName: 'Shopper $i',
          rating: 5,
          text: 'Review $i',
          createdAt: DateTime.utc(2026, 10, 21),
        ),
    ];

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets(
      'an empty reviews list shows the empty copy and can open the '
      'submit sheet', (tester) async {
    final cubit = ReviewsCubit(repository: _Reviews(const []));
    await cubit.load('p1');
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _app(BlocProvider.value(value: cubit, child: const ReviewsView())),
    );
    await tester.pump();

    expect(find.text('No reviews yet — be the first.'), findsOneWidget);
    expect(find.byType(ReviewsInlineList), findsNothing);

    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewSubmitSheet), findsOneWidget);
  });

  testWidgets('loaded reviews render the inline list', (tester) async {
    final cubit = ReviewsCubit(repository: _Reviews(_reviews(3)));
    await cubit.load('p1');
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _app(BlocProvider.value(value: cubit, child: const ReviewsView())),
    );
    await tester.pump();

    expect(find.byType(ReviewsInlineList), findsOneWidget);
    expect(find.byType(ReviewTile), findsNWidgets(3));
    expect(find.text('Customer reviews'), findsOneWidget);
  });

  testWidgets('more than ten reviews are capped with a show-all sheet',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(ReviewsInlineList(reviews: _reviews(12))),
    );
    await tester.pump();

    expect(find.byType(ReviewTile), findsNWidgets(10));
    expect(find.text('Show all (2)'), findsOneWidget);

    await tester.tap(find.text('Show all (2)'));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ReviewTile), findsWidgets);
  });

  testWidgets('ten or fewer reviews hide the show-all affordance',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(ReviewsInlineList(reviews: _reviews(10))),
    );
    await tester.pump();

    expect(find.byType(ReviewTile), findsNWidgets(10));
    expect(find.textContaining('Show all'), findsNothing);
  });
}
