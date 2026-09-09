import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// Shipping Policy page.
class ShippingPolicyPage extends StatelessWidget {
  const ShippingPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.shippingPolicy)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Text(l.shippingPolicyContent,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
