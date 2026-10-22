import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Play Store listing for the Android app (the only store id that exists).
  static final Uri _playStoreUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.albatal.elite');

  void _openStore() {
    launchUrl(_playStoreUri, mode: LaunchMode.externalApplication);
  }

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
              if (isUpdate &&
                  defaultTargetPlatform == TargetPlatform.android) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openStore,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l.update),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
