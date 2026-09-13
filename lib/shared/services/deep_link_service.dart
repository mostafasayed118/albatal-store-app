import 'dart:async';

import 'package:app_links/app_links.dart';

/// Inbound deep-link port (feature-batch §5). Interface-wrapped like
/// the other batch services so consumers depend on the port, not the
/// `app_links` plugin (audit 2026-09-13).
abstract interface class DeepLinkService {
  /// One stream of inbound URIs: the cold-start link (if any) first,
  /// then warm events.
  Stream<Uri> incoming();
}

/// Wraps `app_links` into one stream of inbound URIs. Plugin errors are
/// swallowed so platforms without link support — and VM tests — degrade
/// to silence instead of crashing the shell.
final class AppLinksDeepLinkService implements DeepLinkService {
  AppLinksDeepLinkService({AppLinks? links}) : _links = links ?? AppLinks();

  final AppLinks _links;

  @override
  Stream<Uri> incoming() async* {
    Uri? initial;
    try {
      initial = await _links.getInitialLink();
    } on Exception {
      initial = null;
    }
    if (initial != null) yield initial;
    yield* _links.uriLinkStream.handleError((Object _) {});
  }
}
