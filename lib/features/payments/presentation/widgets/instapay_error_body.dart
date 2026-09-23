import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../payment_error_mapper.dart';

/// Localized fallback shown when the server-derived instructions are absent.
///
/// Shows the mapped error for [errorMessage], never the raw server text
/// (same rule as the sibling fix in payment_method_page.dart).
class InstapayErrorBody extends StatelessWidget {
  const InstapayErrorBody({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Text(
        paymentMessageForCode(l, errorMessage, l.paymentFailedRetry),
        textAlign: TextAlign.center,
      ),
    );
  }
}
