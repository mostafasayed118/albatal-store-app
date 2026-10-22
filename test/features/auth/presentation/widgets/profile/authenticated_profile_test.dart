import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/widgets/profile/authenticated_profile.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../helpers/auth_page_fakes.dart';

final AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

GoRouter _router(AuthCubit cubit, Profile profile) => GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => BlocProvider.value(
            value: cubit,
            child: Scaffold(
              body: AuthenticatedProfile(
                state: AuthState(
                  status: AuthStatus.authenticated,
                  profile: profile,
                ),
                l: _l,
              ),
            ),
          ),
        ),
        for (final path in const [
          '/profile/orders',
          '/profile/addresses',
          '/wishlist',
          '/support',
          '/settings',
          '/home',
        ])
          GoRoute(
            path: path,
            builder: (_, __) => Scaffold(body: Text('SCREEN $path')),
          ),
      ],
    );

Widget _app(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

AuthCubit _cubit() => AuthCubit(
      authRepository: AuthPageFakeAuthRepository(),
      profileRepository: const AuthPageFakeProfileRepository(),
    );

void main() {
  testWidgets('renders the identity card from the profile', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    final router = _router(
      cubit,
      const Profile(id: 'u1', fullName: 'Ahmed', phone: '+201000000000'),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('+201000000000'), findsOneWidget);
    expect(find.text('Premium Member'), findsNothing);
    expect(find.text('Wholesale Partner'), findsNothing);
  });

  testWidgets('a missing profile falls back to the unknown-user copy',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AuthenticatedProfile(
          state: const AuthState(status: AuthStatus.authenticated),
          l: _l,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Guest User'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('premium tier shows the gold membership badge', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    final router = _router(
      cubit,
      const Profile(id: 'u1', fullName: 'Ahmed', tier: MembershipTier.premium),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.text('Premium Member'), findsOneWidget);
    expect(find.text('Free shipping on every order'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
    expect(find.text('Wholesale Partner'), findsNothing);
  });

  testWidgets('wholesale tier shows the partner badge', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    final router = _router(
      cubit,
      const Profile(
          id: 'u1', fullName: 'Ahmed', tier: MembershipTier.wholesale),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.text('Wholesale Partner'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(find.text('Premium Member'), findsNothing);
  });

  const destinations = <(String, String)>[
    ('My Orders', '/profile/orders'),
    ('Shipping Addresses', '/profile/addresses'),
    ('Wishlist', '/wishlist'),
    ('Customer Support', '/support'),
    ('Settings', '/settings'),
  ];

  for (final (label, path) in destinations) {
    testWidgets('"$label" navigates to $path', (tester) async {
      final cubit = _cubit();
      addTearDown(cubit.close);
      final router = _router(
        cubit,
        const Profile(id: 'u1', fullName: 'Ahmed'),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.text('SCREEN $path'), findsOneWidget);
    });
  }

  testWidgets('logging out confirms and returns home', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    final router = _router(
      cubit,
      const Profile(id: 'u1', fullName: 'Ahmed'),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(find.text('SCREEN /home'), findsOneWidget);
    expect(find.text('Signed out'), findsOneWidget);
  });
}
