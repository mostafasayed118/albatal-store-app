import 'package:al_batal_elite/features/auth/presentation/widgets/profile/guest_profile.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

GoRouter _router() => GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => Scaffold(body: GuestProfile(l: _l)),
        ),
        GoRoute(
          path: Routes.signIn,
          builder: (_, __) => const Scaffold(body: Text('SIGN IN')),
        ),
        GoRoute(
          path: Routes.signUp,
          builder: (_, __) => const Scaffold(body: Text('SIGN UP')),
        ),
        GoRoute(
          path: Routes.support,
          builder: (_, __) => const Scaffold(body: Text('SUPPORT')),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the guest sign-in button pushes the sign-in route',
      (tester) async {
    final router = _router();
    await _pump(tester, router);

    await tester.tap(find.widgetWithText(FilledButton, _l.signIn));
    await tester.pumpAndSettle();

    // `push` (not `go`) keeps the location at /profile and layers the new
    // route on top, so the pushed screen is the observable.
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('SIGN UP'), findsNothing);
  });

  testWidgets('the guest sign-up button pushes the sign-up route',
      (tester) async {
    final router = _router();
    await _pump(tester, router);

    await tester.tap(find.widgetWithText(OutlinedButton, _l.signUp));
    await tester.pumpAndSettle();

    expect(find.text('SIGN UP'), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);
  });
}
