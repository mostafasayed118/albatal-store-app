import '../domain/entities/support_channel.dart';
import '../domain/repositories/support_repository.dart';

/// Local fixed-list implementation of [SupportRepository].
///
/// Channels are hardcoded for now. The abstraction earns its keep the
/// moment these values are remote-configured or A/B-tested — the UI
/// stays the same.
final class LocalSupportRepository implements SupportRepository {
  const LocalSupportRepository();

  @override
  List<SupportChannel> getChannels() => const [
        SupportChannel(
          id: 'whatsapp',
          label: 'WhatsApp',
          kind: SupportChannelKind.whatsapp,
          value: 'https://wa.me/201000000000',
        ),
        SupportChannel(
          id: 'email',
          label: 'Email',
          kind: SupportChannelKind.email,
          value: 'support@albatal-store.example',
        ),
        SupportChannel(
          id: 'faq',
          label: 'FAQ',
          kind: SupportChannelKind.faq,
        ),
      ];
}
