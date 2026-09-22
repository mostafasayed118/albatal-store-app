import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../auth/auth.dart';
import 'home_helpers.dart';

/// Home app-bar title: time-of-day greeting + brand name.
///
/// Extracted from `home_page.dart`'s `AppBar` verbatim — the
/// [BlocSelector] isolates rebuilds to first-name changes so catalog
/// emissions never relayout the bar.
final class HomeGreetingTitle extends StatelessWidget {
  const HomeGreetingTitle({super.key, this.clock});

  /// Injectable time source so greeting tests (and previews) can pin an
  /// hour of day; defaults to the wall clock.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocSelector<AuthCubit, AuthState, String?>(
      selector: (state) {
        final fullName = state.profile?.fullName.trim() ?? '';
        if (fullName.isEmpty) return null;
        return fullName.split(RegExp(r'\s+')).first;
      },
      builder: (context, firstName) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            homeGreeting(l, firstName, (clock ?? DateTime.now)()),
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onSurface.withValues(alpha: .6)),
          ),
          Text(
            l.brandName,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: scheme.primary, letterSpacing: 1.15),
          ),
        ],
      ),
    );
  }
}
