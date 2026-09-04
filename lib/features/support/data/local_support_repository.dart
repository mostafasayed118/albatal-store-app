import '../domain/entities/support_channel.dart';
import '../domain/repositories/support_repository.dart';

/// Local fixed-list implementation of [SupportRepository].
///
/// Contact data is owner-verified (WhatsApp +201154580512,
/// al3tar66@gmail.com). Guarded by `test/support_contacts_test.dart` —
/// placeholders must never ship again (live-found 2026-09-04).
final class LocalSupportRepository implements SupportRepository {
  const LocalSupportRepository();

  @override
  List<SupportChannel> getChannels() => const [
        SupportChannel(
          id: 'whatsapp',
          label: 'WhatsApp',
          kind: SupportChannelKind.whatsapp,
          value: 'https://wa.me/201154580512',
        ),
        SupportChannel(
          id: 'email',
          label: 'Email',
          kind: SupportChannelKind.email,
          value: 'al3tar66@gmail.com',
        ),
        SupportChannel(
          id: 'faq',
          label: 'FAQ',
          kind: SupportChannelKind.faq,
        ),
      ];
}
