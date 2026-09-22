import 'dart:async';

import 'package:flutter/material.dart';

import '../../generated/l10n/app_localizations.dart';
import '../extensions/build_context_x.dart';
import '../theme/app_theme.dart';

/// Standalone lock screen. Owns its own [MaterialApp] because the gate sits
/// ABOVE the app's `MaterialApp` (so the theme/locale cubits are unreachable
/// here); it therefore installs the localization delegates itself and lets
/// the platform locale + OS theme mode decide.
///
/// Extracted from `app_lock_gate.dart` (was private `_AppLockScreen`).
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({
    super.key,
    required this.busy,
    required this.showFailure,
    required this.onUnlock,
    this.onSignOut,
  });

  final bool busy;
  final bool showFailure;
  final Future<void> Function() onUnlock;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l = context.l10n;
          final signOut = onSignOut;
          return Scaffold(
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      l.appLocked,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(l.appLockMessage, textAlign: TextAlign.center),
                    if (showFailure) ...[
                      const SizedBox(height: 16),
                      Text(
                        l.appLockFailed,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: busy ? null : () => unawaited(onUnlock()),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: Text(l.appLockUnlock),
                    ),
                    if (signOut != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy ? null : () => unawaited(signOut()),
                        child: Text(l.appLockSignOut),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
