import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:al_batal_elite/shared/services/whatsapp_share_service.dart';

/// No-op share-service fakes for `DetailsPage` harnesses.
///
/// `DetailsPage` takes its share services constructor-injected at the
/// composition root. Widget tests that never trigger a share action use these
/// no-ops so the harness compiles without mocking platform channels. Tests
/// that DO assert share behavior (e.g. `details_whatsapp_share_test.dart`)
/// inject a recording fake instead.
final class NoOpShareService implements ShareService {
  const NoOpShareService();

  @override
  Future<void> shareText(String message) async {}

  @override
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {}
}

final class NoOpWhatsAppShareService implements WhatsAppShareService {
  const NoOpWhatsAppShareService();

  @override
  Future<bool> share(String message) async => false;
}
