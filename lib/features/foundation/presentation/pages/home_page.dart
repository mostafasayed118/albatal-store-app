import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_button.dart';
import '../../../../shared/extensions/build_context_x.dart';

final class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.appTitle, style: Theme.of(context).textTheme.titleLarge)),
    body: ListView(padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 32), children: [
      Text(context.l10n.welcomeTitle, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(context.l10n.welcomeBody, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 32),
      Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.auto_awesome_outlined, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: 16), Text(context.l10n.foundationReady, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8), Text(context.l10n.foundationBody),
        const SizedBox(height: 24),
        AppButton(label: context.l10n.settings, icon: Icons.arrow_forward, onPressed: () => context.go('/settings')),
      ]))),
    ]),
  );
}
