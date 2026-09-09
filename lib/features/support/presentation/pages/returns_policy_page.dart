import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// Returns & Exchange Policy page.
class ReturnsPolicyPage extends StatelessWidget {
  const ReturnsPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.returnsPolicy)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Text(l.returnsPolicyContent,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
