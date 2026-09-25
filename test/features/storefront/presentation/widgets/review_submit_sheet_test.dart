import 'dart:async';
import 'dart:typed_data';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reviews_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews/review_submit_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _ReviewsRepository implements ReviewsRepository {
  final Completer<Result<ProductReview>> submission =
      Completer<Result<ProductReview>>();

  @override
  Future<Result<List<ProductReview>>> fetchForProduct(String productId) async =>
      const Success([]);

  @override
  Future<Result<ProductReview>> submit({
    required String productId,
    required int rating,
    required String text,
    List<int>? photoBytes,
  }) =>
      submission.future;
}

Future<XFile?> _cancelImagePicker() async => null;

Widget _harness(ReviewsCubit cubit, {ReviewImagePicker? pickImage}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: ReviewSubmitSheet(
            pickImage: pickImage ?? _cancelImagePicker,
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'failed submission keeps the sheet mounted until the result lands',
      (tester) async {
    final repository = _ReviewsRepository();
    final cubit = ReviewsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load('p1');
    await tester.pumpWidget(_harness(cubit));

    await tester.enterText(find.byType(TextField), 'Lovely drape');
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.byType(ReviewSubmitSheet), findsOneWidget);

    repository.submission.complete(
      const Failure(AppError('buy first', code: kReviewBuyRequiredCode)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReviewSubmitSheet), findsOneWidget);
    expect(
      find.text('Reviews are open to customers who received this item.'),
      findsOneWidget,
    );
  });

  testWidgets('late photo bytes do not update a disposed sheet',
      (tester) async {
    final repository = _ReviewsRepository();
    final cubit = ReviewsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load('p1');
    final picker = Completer<XFile?>();
    await tester.pumpWidget(_harness(cubit, pickImage: () => picker.future));

    await tester.tap(find.text('Add photo'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    picker.complete(
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'review.jpg',
        mimeType: 'image/jpeg',
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
