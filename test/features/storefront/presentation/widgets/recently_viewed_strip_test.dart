import 'package:al_batal_elite/features/storefront/presentation/cubit/recently_viewed_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/recently_viewed_strip.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/related_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/recently_viewed_store_stub.dart';

Widget _harness(MemoryRecentlyViewedStore store) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => BlocProvider(
              create: (_) => RecentlyViewedCubit(store: store)..load(),
              child: const Scaffold(body: RecentlyViewedStrip()),
            ),
          ),
          GoRoute(
            path: '/product/:id',
            builder: (_, state) =>
                Scaffold(body: Text('detail ${state.pathParameters['id']}')),
          ),
        ],
      ),
    );

void main() {
  testWidgets('empty history renders no section', (tester) async {
    final store = MemoryRecentlyViewedStore();
    await tester.pumpWidget(_harness(store));
    await tester.pump();

    expect(find.text('Recently viewed'), findsNothing);
    expect(find.byType(RelatedCard), findsNothing);
  });

  testWidgets('populated history renders a horizontal card strip',
      (tester) async {
    final store = MemoryRecentlyViewedStore()
      ..entries.addAll([products[0], products[1]]);

    await tester.pumpWidget(_harness(store));
    await tester.pump();

    expect(find.text('Recently viewed'), findsOneWidget);
    expect(find.byType(RelatedCard), findsNWidgets(2));
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.scrollDirection, Axis.horizontal);
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('Egyptian Cotton'), findsOneWidget);
  });

  testWidgets('tapping a card opens the product route', (tester) async {
    final store = MemoryRecentlyViewedStore()..entries.add(products.first);

    await tester.pumpWidget(_harness(store));
    await tester.pump();

    await tester.tap(find.byType(RelatedCard));
    await tester.pumpAndSettle();

    expect(find.text('detail silk-01'), findsOneWidget);
  });
}
