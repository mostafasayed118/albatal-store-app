import '../entities/support_channel.dart';

/// Domain port for the support feature.
///
/// Exposes the contact channels shown on the Support page. The local
/// implementation returns a fixed list today; a remote implementation
/// could pull them from a CMS or remote config without changing the
/// UI.
abstract interface class SupportRepository {
  List<SupportChannel> getChannels();
}
