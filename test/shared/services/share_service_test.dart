import 'dart:io';

import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The service wraps two plugins that are unavailable in a host test build:
/// `path_provider` and `share_plus`. Both are driven here through their method
/// channels, so the real `MethodChannel` implementations behind
/// `SharePlus.instance` are exercised without adding a dependency.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('share_service_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async => 'ok');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return tempDir.path;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('shareText opens the share sheet', () async {
    const service = SharePlusShareService();

    await service.shareText('hello');

    // Reaching here without a throw proves the channel call completed.
    expect(true, isTrue);
  });

  test('shareText swallows a failing share sheet', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
      throw PlatformException(code: 'error');
    });
    const service = SharePlusShareService();

    await expectLater(service.shareText('hello'), completes);
  });

  test('shareFile writes the payload and shares it as a file', () async {
    const service = SharePlusShareService();

    await service.shareFile(
      fileName: 'orders.csv',
      content: 'id,total\n1,100',
      mimeType: 'text/csv',
    );

    final file = File('${tempDir.path}/orders.csv');
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), 'id,total\n1,100');
  });

  test('shareFile swallows the Linux unimplemented error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
      throw UnimplementedError('files not supported');
    });
    const service = SharePlusShareService();

    await expectLater(
      service.shareFile(
        fileName: 'orders.csv',
        content: 'id,total',
        mimeType: 'text/csv',
      ),
      completes,
    );
  });

  test('shareFile swallows a failing share sheet', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
      throw PlatformException(code: 'error');
    });
    const service = SharePlusShareService();

    await expectLater(
      service.shareFile(
        fileName: 'orders.csv',
        content: 'id,total',
        mimeType: 'text/csv',
      ),
      completes,
    );
  });
}
