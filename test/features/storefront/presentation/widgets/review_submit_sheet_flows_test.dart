import 'dart:typed_data';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reviews_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews/review_submit_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

final class _RecordingReviews implements ReviewsRepository {
  _RecordingReviews({this.submitResult});

  Result<ProductReview>? submitResult;
  List<int>? lastPhoto;

  @override
  Future<Result<List<ProductReview>>> fetchForProduct(String productId) async =>
      const Success([]);

  @override
  Future<Result<ProductReview>> submit({
    required String productId,
    required int rating,
    required String text,
    List<int>? photoBytes,
  }) async {
    lastPhoto = photoBytes;
    return submitResult ??
        Success(ProductReview(
          id: 'r1',
          productId: productId,
          authorName: 'Shopper',
          rating: rating,
          text: text,
          createdAt: DateTime.utc(2026, 10, 21),
        ));
  }
}

final class _Compressor implements ImageCompressor {
  Uint8List? input;

  @override
  Future<Uint8List> compress(Uint8List bytes) async {
    input = bytes;
    return Uint8List.fromList(const [9, 9]);
  }
}

Future<XFile?> _pickedImage() async => XFile.fromData(
      Uint8List.fromList(const [1, 2, 3]),
      name: 'review.jpg',
      mimeType: 'image/jpeg',
    );

Widget _host(ReviewsCubit cubit, {ReviewImagePicker? pickImage}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => BlocProvider<ReviewsCubit>.value(
                  value: cubit,
                  child:
                      ReviewSubmitSheet(pickImage: pickImage ?? _pickedImage),
                ),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );

Future<ReviewsCubit> _loadedCubit(ReviewsRepository repository) async {
  final cubit = ReviewsCubit(repository: repository);
  await cubit.load('p1');
  return cubit;
}

void main() {
  testWidgets('picking a photo compresses it and marks the photo attached',
      (tester) async {
    final repository = _RecordingReviews();
    final cubit = await _loadedCubit(repository);
    addTearDown(cubit.close);
    final compressor = _Compressor();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: ReviewSubmitSheet(
              pickImage: _pickedImage,
              imageCompressor: compressor,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();

    expect(compressor.input, const [1, 2, 3]);
    expect(find.text('Photo attached'), findsOneWidget);
  });

  testWidgets('the default picker failure is swallowed (text-only review)',
      (tester) async {
    final repository = _RecordingReviews();
    final cubit = await _loadedCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: ReviewSubmitSheet()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();

    expect(find.text('Photo attached'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a star updates the rating and submits it',
      (tester) async {
    final repository = _RecordingReviews();
    final cubit = await _loadedCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: ReviewSubmitSheet()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.star).first);
    await tester.pump();

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNWidgets(4));
  });

  testWidgets('successful submission pops the sheet', (tester) async {
    final repository = _RecordingReviews();
    final cubit = await _loadedCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Lovely drape');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewSubmitSheet), findsNothing);
    expect(find.text('open sheet'), findsOneWidget);
  });

  testWidgets('unavailable submissions show the dedicated message',
      (tester) async {
    final repository = _RecordingReviews(
      submitResult: const Failure(AppError('x', code: kReviewUnavailableCode)),
    );
    final cubit = await _loadedCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: ReviewSubmitSheet()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Reviews are unavailable right now.'), findsOneWidget);
  });

  testWidgets('other submission failures show the generic save copy',
      (tester) async {
    final repository = _RecordingReviews(
      submitResult: const Failure(AppError('boom')),
    );
    final cubit = await _loadedCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: ReviewSubmitSheet()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save. Please try again."), findsOneWidget);
  });
}
