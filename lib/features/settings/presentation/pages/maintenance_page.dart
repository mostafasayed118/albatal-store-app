import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/app_colors.dart';

/// Full-screen service/forced-update gate (feature-batch §13). Shown
/// when remote config flips maintenance mode, or the running version is
/// below the configured minimum. Intentionally dependency-free so it
/// renders even when the rest of the app cannot.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key, this.isUpdate = false});

  /// True when shown for a forced update rather than maintenance.
  final bool isUpdate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUpdate ? Icons.system_update_outlined : Icons.engineering,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isUpdate ? l.updateRequiredTitle : l.maintenanceTitle,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isUpdate ? l.updateRequiredBody : l.maintenanceBody,
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
