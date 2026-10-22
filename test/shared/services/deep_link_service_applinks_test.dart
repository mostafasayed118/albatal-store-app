import 'dart:async';

import 'package:al_batal_elite/shared/services/deep_link_service.dart';
// `AppLinksPlatform` is the seam this file fakes. The interface package is
// transitive, so it must not be added to pubspec.
// ignore: depend_on_referenced_packages
import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeAppLinksPlatform extends AppLinksPlatform {
  _FakeAppLinksPlatform({this.initial, this.throwOnInitial = false});

  final Uri? initial;
  final bool throwOnInitial;
  final StreamController<Uri> controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async {
    if (throwOnInitial) throw Exception('platform link lookup failed');
    return initial;
  }

  @override
  Stream<Uri> get uriLinkStream => controller.stream;
}

/// Subscribes without `take`, so the source is still listened to when the
/// fake platform closes — that lets `AppLinks` clear its singleton stream
/// cache between tests in this file.
Future<(List<Uri>, Future<void>)> _collect(AppLinksDeepLinkService service) {
  final events = <Uri>[];
  final done = Completer<void>();
  service.incoming().listen(
        events.add,
        onError: (_) {},
        onDone: done.complete,
      );
  return Future.value((events, done.future));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLinksPlatform original;

  setUp(() {
    original = AppLinksPlatform.instance;
  });

  tearDown(() {
    AppLinksPlatform.instance = original;
  });

  test('a failed cold-start lookup degrades to the warm stream', () async {
    final platform = _FakeAppLinksPlatform(throwOnInitial: true);
    AppLinksPlatform.instance = platform;

    final (events, done) = await _collect(AppLinksDeepLinkService());

    await Future<void>.delayed(Duration.zero);
    final first = Uri.parse('albatal://product/p1');
    final second = Uri.parse('albatal://product/p2');
    platform.controller.add(first);
    platform.controller.addError(Exception('stream error is swallowed'));
    platform.controller.add(second);

    await platform.controller.close();
    await done;

    expect(events, [first, second]);
  });

  test('a cold-start link is yielded before warm events', () async {
    final initial = Uri.parse('albatal://product/cold');
    final platform = _FakeAppLinksPlatform(initial: initial);
    AppLinksPlatform.instance = platform;

    final (events, done) = await _collect(AppLinksDeepLinkService());

    await Future<void>.delayed(Duration.zero);
    final warm = Uri.parse('albatal://product/warm');
    platform.controller.add(warm);

    await platform.controller.close();
    await done;

    expect(events, [initial, warm]);
  });
}
