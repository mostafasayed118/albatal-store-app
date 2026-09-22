import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/auth_cubit.dart';
import '../widgets/profile/authenticated_profile.dart';
import '../widgets/profile/guest_profile.dart';

/// Profile entry — delegates to [GuestProfile] / [AuthenticatedProfile]
/// (one widget per file).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myProfile)),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state.isGuest) {
            return GuestProfile(l: l);
          }
          return AuthenticatedProfile(state: state, l: l);
        },
      ),
    );
  }
}
