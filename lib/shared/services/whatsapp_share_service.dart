import 'package:url_launcher/url_launcher.dart';

/// Builds the wa.me universal link for a prefill message (task #13).
///
/// Pure so it is testable without platform channels. The message is
/// percent-encoded with [Uri.encodeComponent] — spaces stay `%20` (never
/// `+`, which wa.me would render literally) and any script (Arabic
/// included) survives as valid UTF-8 escapes, so RTL text round-trips.
Uri whatsappShareUrl(String message) =>
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

/// Port over the `url_launcher` platform channel (task #13).
///
/// Same interface-wrapping seam as `DeepLinkService`/`PushService`:
/// widget tests inject a recording fake instead of mocking the plugin.
abstract interface class ExternalLinkLauncher {
  /// Opens [uri] in an external app. Returns `false` — never throws —
  /// when no external app can take the link or the channel fails.
  Future<bool> launchExternal(Uri uri);
}

/// `url_launcher` implementation of [ExternalLinkLauncher].
final class UrlLauncherExternalLinkLauncher implements ExternalLinkLauncher {
  const UrlLauncherExternalLinkLauncher();

  @override
  Future<bool> launchExternal(Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // No handler / channel unavailable — the caller shows feedback.
      return false;
    }
  }
}

/// WhatsApp-first product share (task #13).
abstract interface class WhatsAppShareService {
  /// Sends [message] as the prefill text of a wa.me universal link.
  /// Returns `true` when an external app took the link.
  Future<bool> share(String message);
}

/// wa.me implementation of [WhatsAppShareService].
final class WaMeWhatsAppShareService implements WhatsAppShareService {
  const WaMeWhatsAppShareService(this._launcher);

  final ExternalLinkLauncher _launcher;

  @override
  Future<bool> share(String message) =>
      _launcher.launchExternal(whatsappShareUrl(message));
}
