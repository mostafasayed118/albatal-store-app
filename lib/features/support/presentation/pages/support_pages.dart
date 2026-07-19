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
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.privacyPolicyContent, style: Theme.of(context).textTheme.bodyLarge),
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
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.termsOfServiceContent, style: Theme.of(context).textTheme.bodyLarge),
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
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.shippingPolicyContent, style: Theme.of(context).textTheme.bodyLarge),
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
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.returnsPolicyContent, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Customer Support page.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.customerSupport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat),
              title: Text(l.whatsappSupport),
              subtitle: Text(l.whatsappSupportDescription),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: Launch WhatsApp
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email),
              title: Text(l.emailSupport),
              subtitle: Text(l.emailSupportAddress),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: Launch email
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l.faq),
              subtitle: Text(l.faqDescription),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to FAQ
              },
            ),
          ),
        ],
      ),
    );
  }
}
