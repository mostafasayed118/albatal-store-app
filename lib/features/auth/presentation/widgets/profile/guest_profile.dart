import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../generated/l10n/app_localizations.dart';
import '../../../../../shared/routing/app_routes.dart';

/// Guest profile placeholder — extracted from `profile_page.dart` verbatim
/// (was private `_GuestProfile`).
class GuestProfile extends StatelessWidget {
  const GuestProfile({super.key, required this.l});
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
              onPressed: () => context.push(Routes.signIn),
              child: Text(l.signIn),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push(Routes.signUp),
              child: Text(l.signUp),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push(Routes.support),
              icon: const Icon(Icons.support_agent_outlined),
              label: Text(l.customerSupport),
            ),
          ],
        ),
      ),
    );
  }
}
