import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/sign_up_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/auth_page_fakes.dart';

/// The confirm field carries the keyboard "done" action, so the IME path
/// is a second, independent way to submit the sign-up form.
void main() {
  testWidgets('the keyboard done action submits the sign-up form',
      (tester) async {
    final auth = AuthPageFakeAuthRepository();
    final cubit = AuthCubit(
      authRepository: auth,
      profileRepository: const AuthPageFakeProfileRepository(),
    );
    addTearDown(cubit.close);
    await cubit.checkSession();

    final router = GoRouter(
      initialLocation: '/sign-up',
      routes: [
        GoRoute(
          path: '/sign-up',
          builder: (_, __) => BlocProvider.value(
            value: cubit,
            child: const SignUpPage(),
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (_, __) => const Scaffold(body: Text('SIGN_IN_SCREEN')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME_SCREEN')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ahmed');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret123');
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(auth.signUpCalls, hasLength(1));
    expect(auth.signUpCalls.single.email, 'a@b.com');
    expect(auth.signUpCalls.single.fullName, 'Ahmed');
  });
}
