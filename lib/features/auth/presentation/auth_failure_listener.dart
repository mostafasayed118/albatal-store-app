import 'package:flutter/material.dart';

import '../../../shared/components/feedback.dart';
import '../../../shared/extensions/build_context_x.dart';
import '../../../shared/l10n/failure_copy.dart';
import 'cubit/auth_cubit.dart';

/// The single auth-failure snackbar (audit 2026-09-21 duplication cluster:
/// the same listener arm was written three times in sign-in, forgot and
/// reset — sign-up carried a fourth copy).
///
/// Code-first copy: [failureText] localizes by [AuthState.errorCode]; the
/// raw message is English diagnosis and only shows for uncoded failures.
void showAuthFailure(BuildContext context, AuthState state) {
  if (state.errorMessage == null) return;
  showFloatingError(
    context,
    failureText(context.l10n,
        code: state.errorCode,
        message: state.errorMessage,
        fallback: context.l10n.failureUnexpected),
  );
}
