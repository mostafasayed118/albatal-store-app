import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/iterable_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/entities/support_channel.dart';
import '../../domain/repositories/support_repository.dart';

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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.comingSoon)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
