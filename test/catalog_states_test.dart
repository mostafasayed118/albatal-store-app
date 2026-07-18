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

/// Repository that starts failing, then succeeds on the second call.
class FlakeyCatalogRepository implements CatalogRepository {
  int calls = 0;
  @override
  Future<Result<List<Product>>> fetchProducts() async {
    calls++;
    return calls == 1
        ? Failure(AppError('Catalog unavailable'))
        : Success(List.of(products));
  }

  @override
  Future<Result<List<String>>> fetchCategories() async {
    calls++;
    return calls <= 2
        ? Failure(AppError('Categories unavailable'))
        : Success(List.of(categories));
  }
}

Widget _harness(CatalogRepository repo) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => CatalogCubit(repo),
        child: const HomePage(),
      ),
    );

void main() {
  testWidgets('home shows error state with retry when repository fails',
      (tester) async {
    final repo = FlakeyCatalogRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();

    // First load fails → error state with retry button.
    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Tap retry → second load succeeds → grid appears.
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackView), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('home shows loading state on initial build',
      (tester) async {
    final repo = FlakeyCatalogRepository()..calls = 100; // force success
    await tester.pumpWidget(_harness(repo));
    // Before the async load completes, we should see loading.
    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
  });
}
