/// A support contact channel surfaced to the user on the Support page.
///
/// The presentation layer reads from [SupportRepository] rather than
/// hardcoding channel URLs and addresses in the widget tree, so the
/// values can change (or be remote-configured) without touching UI.
final class SupportChannel {
  const SupportChannel({
    required this.id,
    required this.label,
    required this.kind,
    this.value,
    this.description,
  });

  final String id;
  final String label;
  final SupportChannelKind kind;
  final String? value;
  final String? description;
}

enum SupportChannelKind { whatsapp, email, faq, externalLink }
