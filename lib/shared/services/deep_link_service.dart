import 'dart:async';

import 'package:app_links/app_links.dart';

/// Wraps `app_links` into one stream of inbound URIs: the cold-start
/// link (if any) first, then warm events. Plugin errors are swallowed
/// so platforms without link support — and VM tests — degrade to
/// silence instead of crashing the shell.
final class DeepLinkService {
  DeepLinkService({AppLinks? links}) : _links = links ?? AppLinks();

  final AppLinks _links;

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
