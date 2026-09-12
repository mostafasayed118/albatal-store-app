import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/profile.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/app_colors.dart';
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
        ), // Stitch mockup (Categories/Profile/Orders) shows a Premium Member
        // badge under the identity card — now driven by the real,
        // admin-managed membership_tier (migration 046), so only
        // premium-tier customers see it.
        if (profile?.tier == MembershipTier.premium) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.workspace_premium,
                  size: 18, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                l.premiumMember,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.gold, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.premiumFreeShipping,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
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
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l.settings),
          // Drill-in chevron points in the reading direction (flips in RTL).
          trailing: Icon(context.directionalTrailingIcon),
          onTap: () => context.push('/settings'),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () async {
            await context.read<AuthCubit>().signOut();
            if (context.mounted) {
              showConfirmation(context, l.signedOut);
              context.go('/home');
            }
          },
          icon: const Icon(Icons.logout),
          label: Text(l.logOut),
        ),
      ],
    );
  }
}
