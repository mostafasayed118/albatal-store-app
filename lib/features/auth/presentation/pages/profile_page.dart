import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/auth_cubit.dart';

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
            return _GuestProfile(l: l);
          }
          return _AuthenticatedProfile(state: state, l: l);
        },
      ),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(l.signInToViewProfile,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push('/sign-in'),
              child: Text(l.signIn),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/sign-up'),
              child: Text(l.signUp),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push('/support'),
              icon: const Icon(Icons.support_agent_outlined),
              label: Text(l.customerSupport),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthenticatedProfile extends StatelessWidget {
  const _AuthenticatedProfile({required this.state, required this.l});
  final AuthState state;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 30,
              child: Text(profile?.fullName.isNotEmpty == true
                  ? profile!.fullName.characters.first
                  : '?'),
            ),
            title: Text(profile?.fullName ?? l.unknownUser),
            subtitle: Text(profile?.phone ?? ''),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(l.myOrders),
          // Drill-in chevron points in the reading direction (flips in RTL).
          trailing: Icon(context.directionalTrailingIcon),
          onTap: () => context.push('/profile/orders'),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(l.shippingAddresses),
          // Drill-in chevron points in the reading direction (flips in RTL).
          trailing: Icon(context.directionalTrailingIcon),
          onTap: () => context.push('/profile/addresses'),
        ),
        ListTile(
          leading: const Icon(Icons.favorite_border),
          title: Text(l.wishlist),
          // Drill-in chevron points in the reading direction (flips in RTL).
          trailing: Icon(context.directionalTrailingIcon),
          onTap: () => context.go('/wishlist'),
        ),
        ListTile(
          leading: const Icon(Icons.support_agent_outlined),
          title: Text(l.customerSupport),
          // Drill-in chevron points in the reading direction (flips in RTL).
          trailing: Icon(context.directionalTrailingIcon),
          onTap: () => context.push('/support'),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () async {
            await context.read<AuthCubit>().signOut();
            if (context.mounted) context.go('/home');
          },
          icon: const Icon(Icons.logout),
          label: Text(l.logOut),
        ),
      ],
    );
  }
}
