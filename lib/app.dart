import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/addresses/domain/repositories/address_repository.dart';
import 'features/addresses/presentation/cubit/addresses_cubit.dart';
import 'features/admin/domain/repositories/admin_repository.dart';
import 'features/admin/presentation/cubit/admin_cubit.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/repositories/profile_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/settings/presentation/cubit/settings_state.dart';
import 'features/storefront/domain/repositories/cart_repository.dart';
import 'features/storefront/domain/repositories/catalog_repository.dart';
import 'features/storefront/domain/repositories/orders_repository.dart';
import 'features/storefront/domain/repositories/wishlist_repository.dart';
import 'features/storefront/presentation/cubit/cart_cubit.dart';
import 'features/storefront/presentation/cubit/catalog_cubit.dart';
import 'features/storefront/presentation/cubit/orders_cubit.dart';
import 'features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'generated/l10n/app_localizations.dart';
import 'shared/routing/app_router.dart';
import 'shared/services/service_locator.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/environment_banner.dart';

final class AlBatalApp extends StatelessWidget {
  const AlBatalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        providers: [
          BlocProvider(
              create: (_) =>
                  SettingsCubit(getIt<SettingsRepository>())..load()),
          BlocProvider(
              create: (_) => CatalogCubit(getIt<CatalogRepository>())..load()),
          BlocProvider(
              create: (_) => CartCubit(
                    getIt<CartRepository>(),
                    productLookup: getIt<CatalogRepository>().findProductById,
                  )..restore()),
          BlocProvider(
              create: (_) =>
                  WishlistCubit(getIt<WishlistRepository>())..restore()),
          BlocProvider(
              create: (_) => OrdersCubit(getIt<OrdersRepository>())..restore()),
          BlocProvider(
              create: (_) =>
                  AddressesCubit(getIt<AddressRepository>())..load()),
          BlocProvider(
              create: (_) => AuthCubit(
                    authRepository: getIt<AuthRepository>(),
                    profileRepository: getIt<ProfileRepository>(),
                  )..checkSession()),
          BlocProvider(create: (_) => AdminCubit(getIt<AdminRepository>())),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
            buildWhen: (a, b) =>
                a.themeMode != b.themeMode || a.locale != b.locale,
            builder: (_, s) => MaterialApp.router(
                  title: 'Al Batal Elite',
                  debugShowCheckedModeBanner: false,
                  color: AppTheme.emerald,
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: s.themeMode,
                  locale: s.locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: appRouter,
                  builder: (context, child) => _SplashTransition(
                    child: EnvironmentBanner(child: child!),
                  ),
                )));
  }
}

/// Brief emerald overlay that fades out on the first frame, preventing a
/// flash between the native splash screen and the Flutter content.
class _SplashTransition extends StatefulWidget {
  const _SplashTransition({required this.child});
  final Widget child;

  @override
  State<_SplashTransition> createState() => _SplashTransitionState();
}

class _SplashTransitionState extends State<_SplashTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        if (_opacity.isCompleted) return child!;
        return ColoredBox(
          color: AppTheme.emerald.withValues(alpha: _opacity.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
