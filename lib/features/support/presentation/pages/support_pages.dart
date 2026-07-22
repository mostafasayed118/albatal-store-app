import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
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
        padding: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.all(16),
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
/// Channels are sourced from [SupportRepository] rather than hardcoded, and
/// every tile performs a real action: WhatsApp/email copy their contact
/// value to the clipboard (with a confirmation snackbar), and FAQ navigates
/// to the in-app [FaqPage]. No tile is a no-op.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key, SupportRepository? repository})
      : _repository = repository;

  final SupportRepository? _repository;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repository = _repository ?? getIt<SupportRepository>();
    final channels = repository.getChannels();
    return Scaffold(
      appBar: AppBar(title: Text(l.customerSupport)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _SupportTile(channel: channels[index]),
      ),
    );
  }
}

/// A single support channel rendered as a tappable card.
class _SupportTile extends StatelessWidget {
  const _SupportTile({required this.channel});

  final SupportChannel channel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    switch (channel.kind) {
      case SupportChannelKind.faq:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l.faq),
            subtitle: Text(l.faqDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/faq'),
          ),
        );
      case SupportChannelKind.whatsapp:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.chat),
            title: Text(l.whatsappSupport),
            subtitle: Text(channel.value ?? l.whatsappSupportDescription),
            trailing: const Icon(Icons.copy),
            onTap: () => _copyValue(context),
          ),
        );
      case SupportChannelKind.email:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.email),
            title: Text(l.emailSupport),
            subtitle: Text(channel.value ?? l.emailSupportAddress),
            trailing: const Icon(Icons.copy),
            onTap: () => _copyValue(context),
          ),
        );
      case SupportChannelKind.externalLink:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(channel.label),
            subtitle: channel.value != null ? Text(channel.value!) : null,
            trailing: const Icon(Icons.copy),
            onTap: () => _copyValue(context),
          ),
        );
    }
  }

  /// Copies the channel value to the clipboard and confirms via snackbar.
  /// Copy is used instead of launching an external app so the action works
  /// without adding a URL-launcher dependency and is fully testable.
  Future<void> _copyValue(BuildContext context) async {
    final value = channel.value;
    if (value == null || value.isEmpty) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    messenger.showSnackBar(
      SnackBar(content: Text(l.copiedToClipboard(value))),
    );
  }
}

/// In-app Frequently Asked Questions page. Content is fully local (from
/// l10n) so it works offline and needs no backend.
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = <(String, String)>[
      (l.faqShippingQuestion, l.faqShippingAnswer),
      (l.faqReturnsQuestion, l.faqReturnsAnswer),
      (l.faqPaymentQuestion, l.faqPaymentAnswer),
      (l.faqOrderTrackingQuestion, l.faqOrderTrackingAnswer),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.faq)),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          for (final (question, answer) in entries)
            Card(
              child: ExpansionTile(
                title: Text(question),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(answer, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
