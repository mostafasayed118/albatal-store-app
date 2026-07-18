import 'dart:async';

import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/storefront_cubits.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository that always fails — for testing the error state.
final class FailingCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Failure(AppError('Catalog unavailable'));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Failure(AppError('Categories unavailable'));
}

Widget _harness(CatalogRepository repo) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => CatalogCubit(repo)..load(),
        child: const HomePage(),
      ),
    );

void main() {
  testWidgets('home shows error state with retry when repository fails',
      (tester) async {
    await tester.pumpWidget(_harness(FailingCatalogRepository()));
    // Advance past the async load() and the 1s countdown timer.
    await tester.pump(const Duration(seconds: 1));

    // First load fails → error state with retry button.
    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);

    // Tap retry → load called again (still fails) → still shows error.
    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FeedbackView), findsOneWidget);
  });

  testWidgets('home shows loading state on initial build',
      (tester) async {
    // Use a repository that never completes — keeps us in loading.
    await tester.pumpWidget(_harness(_NeverCompletesRepository()));
    await tester.pump(); // One frame to build.

    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
  });
}

/// Repository whose fetch never completes — keeps the cubit in loading state.
class _NeverCompletesRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() =>
      Completer<Result<List<Product>>>().future;

  @override
  Future<Result<List<String>>> fetchCategories() =>
      Completer<Result<List<String>>>().future;
}
