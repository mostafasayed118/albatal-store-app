import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/iterable_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/entities/support_channel.dart';
import '../../domain/repositories/support_repository.dart';

/// Customer Support page.
///
/// Contact targets come from [SupportRepository] — never hardcoded here
/// (live-found 2026-09-04: a fake wa.me number shipped in this file).
/// The optional [supportRepository] override is the test seam (mirrors
/// the CheckoutPage/PaymentMethodPage convention); production resolves
/// the GetIt-registered repository.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key, this.supportRepository});

  final SupportRepository? supportRepository;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final channels =
        (supportRepository ?? getIt<SupportRepository>()).getChannels();
    SupportChannel? byKind(SupportChannelKind kind) =>
        channels.where((c) => c.kind == kind).firstOrNull;
    final whatsapp = byKind(SupportChannelKind.whatsapp);
    final email = byKind(SupportChannelKind.email);
    return Scaffold(
      appBar: AppBar(title: Text(l.customerSupport)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          if (whatsapp?.value != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat),
                title: Text(l.whatsappSupport),
                subtitle: Text(l.whatsappSupportDescription),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  final uri = Uri.parse(whatsapp!.value!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    // The channel that was tapped must acknowledge the
                    // attempt even when no external app can take it.
                    if (context.mounted) {
                      showFloatingError(context, context.l10n.couldNotOpenLink);
                    }
                  }
                },
              ),
            ),
          if (whatsapp?.value != null) const SizedBox(height: 12),
          if (email?.value != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: Text(l.emailSupport),
                // The address itself is the subtitle: single source of
                // truth (repository), no l10n mirror to drift.
                subtitle: Text(email!.value!),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  final uri = Uri.parse('mailto:${email.value!}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    // The channel that was tapped must acknowledge the
                    // attempt even when no mail app can take it.
                    if (context.mounted) {
                      showFloatingError(context, context.l10n.couldNotOpenLink);
                    }
                  }
                },
              ),
            ),
          if (email?.value != null) const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l.faq),
              subtitle: Text(l.faqDescription),
              // Drill-in chevron points in the reading direction (flips in RTL).
              trailing: Icon(context.directionalTrailingIcon),
              onTap: () {
                showConfirmation(context, l.comingSoon);
              },
            ),
          ),
        ],
      ),
    );
  }
}
