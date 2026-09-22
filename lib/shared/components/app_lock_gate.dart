import 'dart:async';

import 'package:flutter/material.dart';

import '../services/biometric_service.dart';
import '../services/logger.dart';
import 'app_lock_screen.dart';

/// Biometric app-lock gate (feature-batch §15).
///
/// Wraps the app shell and renders a lock screen until the user
/// authenticates. [child] is deliberately NOT inflated while locked.
///
/// FAIL-CLOSED CONTRACT (audit fix)
/// -------------------------------
/// The previous implementation lived inside `_AlBatalAppState` and had two
/// defects:
///
///   1. It failed OPEN — a cancelled or failed prompt cleared the lock flag
///      and let the app through, so enabling the opt-in protected nothing.
///      The lock is now released only by a successful authentication, or by
///      the explicit sign-out escape below.
///   2. It locked *after* an awaited capability probe, leaving a window in
///      which the shell rendered unlocked. The lock flag is now set before
///      the first `await`, so the first frame is already locked.
///
/// The single legitimate "release without authenticating" case is a device
/// that cannot authenticate at all (no biometrics AND no device credential):
/// keeping the lock would trap the user behind an unusable screen forever.
/// That case is logged, never silent.
///
/// ESCAPE HATCH: when [onSignOut] is supplied the lock screen offers a sign
/// out action. It unlocks only *after* the sign-out callback completes, so
/// it clears the session and local PII snapshots instead of bypassing the
/// lock — a user who cannot authenticate is never permanently locked out.
///
/// Dependencies arrive through the constructor (feature-first convention: no
/// service-locator lookups inside the widget), so the gate is unit-testable
/// with fakes — see `test/shared/components/app_lock_gate_test.dart`.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
    this.biometrics,
    this.prefs,
    this.onSignOut,
  });

  /// The app shell, rendered only once the lock is released.
  final Widget child;

  /// Authenticator. Null (tests / unsupported platform) disables the gate.
  final BiometricService? biometrics;

  /// Opt-in persistence. Null or `enabled == false` disables the gate.
  final AppLockPrefsStore? prefs;

  /// Sign-out escape hatch; null hides the action on the lock screen.
  final Future<void> Function()? onSignOut;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

/// OS dialog copy. The platform prompt renders its own app-name chrome, and
/// the gate sits above `MaterialApp` (so no `AppLocalizations` is reachable
/// when the initial automatic prompt fires) — deliberately not localized.
const _unlockReason = 'Unlock Al Batal Elite';

class _AppLockGateState extends State<AppLockGate> {
  bool _locked = false;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final prefs = widget.prefs;
    if (prefs == null || !prefs.enabled) return;
    // Lock on the FIRST frame, before any await (defect 2 above).
    _locked = true;
    unawaited(_unlockFlow());
  }

  /// Prompts when the device can authenticate; releases only when it cannot.
  Future<void> _unlockFlow() async {
    final biometrics = widget.biometrics;
    var usable = false;
    if (biometrics != null) {
      try {
        usable = await biometrics.canAuthenticate();
      } on Exception catch (e) {
        Log.w('app lock: capability probe failed.', error: e);
      }
    }
    if (!mounted) return;
    if (!usable) {
      // Nothing on this device can authenticate the user; trapping them
      // behind the lock screen would be worse than releasing it.
      Log.w('app lock: no usable authenticator — releasing');
      setState(() {
        _locked = false;
        _failed = false;
      });
      return;
    }
    await _prompt();
  }

  /// Runs the platform prompt. Only a `true` result unlocks.
  Future<void> _prompt() async {
    final biometrics = widget.biometrics;
    if (biometrics == null || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var accepted = false;
    try {
      accepted = await biometrics.authenticate(reason: _unlockReason);
    } on Exception catch (e) {
      // `LocalBiometricService` already converts plugin errors to `false`;
      // this guards any other implementation.
      Log.w('app lock: authentication threw.', error: e);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !accepted;
      if (accepted) _locked = false;
    });
    if (!accepted) {
      Log.w('app lock: authentication not completed — staying locked');
    }
  }

  /// Signs out (clearing session + local snapshots), then unlocks. A failed
  /// sign-out keeps the app locked: the escape must never become a bypass.
  Future<void> _signOut() async {
    final signOut = widget.onSignOut;
    if (signOut == null) return;
    try {
      await signOut();
    } on Object catch (e) {
      // `on Object`, not just Exception: any failure — including a thrown
      // Error — must keep the lock. Letting it propagate would crash the
      // lock screen and defeat the fail-closed contract this escape exists
      // to preserve (verified by the no-bypass test).
        Log.w('app lock: sign-out escape failed.', error: e);
      return;
    }
    if (!mounted) return;
    setState(() {
      _locked = false;
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return AppLockScreen(
      busy: _busy,
      showFailure: _failed,
      onUnlock: _prompt,
      onSignOut: widget.onSignOut == null ? null : _signOut,
    );
  }
}
