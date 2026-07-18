import 'package:al_batal_elite/features/storefront/presentation/cubit/storefront_cubits.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/shared/extensions/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';

Widget _harness({required Locale locale}) {
  SharedPreferences.setMockInitialValues({});
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CatalogCubit()),
        BlocProvider(
            create: (_) =>
                CartCubit(MemoryStorefrontPersistence())..restore()),
        BlocProvider(
            create: (_) =>
                WishlistCubit(MemoryStorefrontPersistence())..restore()),
      ],
      child: const HomePage(),
    ),
  );
}

void main() {
  testWidgets('home search clear and settings buttons expose localized tooltips',
      (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('en')));
    await tester.pumpAndSettle();

    // Settings tooltip is always visible in the app bar.
    expect(find.byTooltip('Open settings'), findsOneWidget);

    // Type a query so the clear button replaces the mic button.
    await tester.enterText(find.byType(TextField), 'silk');
    await tester.pump();

    expect(find.byTooltip('Clear search'), findsOneWidget);
    expect(find.byTooltip('Voice search'), findsNothing);
  });

  testWidgets('app boots in Arabic and resolves RTL directionality',
      (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.byType(HomePage))),
        TextDirection.rtl);

    final context = tester.element(find.byType(HomePage));
    expect(context.l10n.brandName, 'البطل إيليت');
    expect(context.l10n.addToCart, 'أضف إلى السلة');

    // Arabic tooltip resolves too, proving the icon button labels localize.
    expect(find.byTooltip('فتح الإعدادات'), findsOneWidget);
  });

  testWidgets('AppLocalizations delegate is registered for the home tree',
      (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('en')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomePage));
    expect(AppLocalizations.of(context), isNotNull);
    expect(context.l10n.appTitle, 'Al Batal Elite');
  });
}
