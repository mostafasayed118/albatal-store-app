import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/addresses/domain/repositories/address_repository.dart';
import 'features/addresses/presentation/cubit/addresses_cubit.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/settings/presentation/cubit/settings_state.dart';
import 'features/storefront/data/local_catalog_repository.dart';
import 'features/storefront/data/storefront_persistence.dart';
import 'features/storefront/presentation/cubit/cart_cubit.dart';
import 'features/storefront/presentation/cubit/catalog_cubit.dart';
import 'features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'generated/l10n/app_localizations.dart';
import 'shared/routing/app_router.dart';
import 'shared/services/service_locator.dart';
import 'shared/theme/app_theme.dart';

final class AlBatalApp extends StatelessWidget {
  const AlBatalApp({super.key});
  @override
  Widget build(BuildContext context) {
    final persistence = LocalStorefrontPersistence(getIt<SharedPreferences>());
    return MultiBlocProvider(
        providers: [
          BlocProvider(
              create: (_) =>
                  SettingsCubit(getIt<SettingsRepository>())..load()),
          BlocProvider(
              create: (_) => CatalogCubit(LocalCatalogRepository())..load()),
          BlocProvider(create: (_) => CartCubit(persistence)..restore()),
          BlocProvider(create: (_) => WishlistCubit(persistence)..restore()),
          BlocProvider(
              create: (_) => AddressesCubit(getIt<AddressRepository>())..load())
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
            buildWhen: (a, b) =>
                a.themeMode != b.themeMode || a.locale != b.locale,
            builder: (_, s) => MaterialApp.router(
                title: 'Al Batal Elite',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: s.themeMode,
                locale: s.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: appRouter)));
  }
}
