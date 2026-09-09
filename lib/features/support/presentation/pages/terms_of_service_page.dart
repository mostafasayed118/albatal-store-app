import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// Terms of Service page.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.termsOfService)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Text(l.termsOfServiceContent,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
