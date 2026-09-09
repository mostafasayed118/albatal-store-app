import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// Privacy Policy page.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyPolicy)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Text(l.privacyPolicyContent,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
