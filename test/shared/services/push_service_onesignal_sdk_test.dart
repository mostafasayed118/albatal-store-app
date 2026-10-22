import 'package:al_batal_elite/shared/services/push_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// The concrete `OneSignalSdk` adapter only runs on a device today. The
/// plugin talks over method channels, so the VM can drive the same seam
/// the app uses in production by mocking those channels.
const _channels = <String>[
  'OneSignal',
  'OneSignal#debug',
  'OneSignal#inappmessages',
  'OneSignal#user',
  'OneSignal#pushsubscription',
  'OneSignal#notifications',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  String? hostSubscriptionId;
  bool permissionFails = false;

  void mockChannels() {
    for (final name in _channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
        calls.add(call);
        if (name == 'OneSignal#pushsubscription' &&
            call.method == 'OneSignal#pushSubscriptionId') {
          return hostSubscriptionId;
        }
        if (name == 'OneSignal#notifications') {
          if (call.method == 'OneSignal#requestPermission') {
            if (permissionFails) {
              throw MissingPluginException('OneSignal#notifications');
            }
            return true;
          }
          if (call.method == 'OneSignal#permission') return true;
        }
        return null;
      });
    }
  }

  setUp(() {
    calls.clear();
    hostSubscriptionId = null;
    permissionFails = false;
    mockChannels();
  });

  tearDown(() {
    for (final name in _channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  /// Simulates the native side reporting a new push subscription.
  Future<void> fireSubscriptionChange(String id) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'OneSignal#pushsubscription',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('OneSignal#onPushSubscriptionChange', {
          'current': {'id': id, 'token': 'token-$id', 'optedIn': true},
          'previous': {'id': null, 'token': null, 'optedIn': false},
        }),
      ),
      (_) {},
    );
  }

  group('OneSignalSdk', () {
    test('reports no subscription id before the host assigns one', () async {
      hostSubscriptionId = null;
      await OneSignal.User.pushSubscription.lifecycleInit();

      expect(OneSignalSdk().subscriptionId, isNull);
    });

    test('reports the host subscription id once it is assigned', () async {
      hostSubscriptionId = 'sub-123';
      await OneSignal.User.pushSubscription.lifecycleInit();

      expect(OneSignalSdk().subscriptionId, 'sub-123');
    });

    test('requesting permission prompts the host for permission', () async {
      final granted = await OneSignalSdk().requestPermission();

      expect(granted, isTrue);
      expect(
        calls,
        contains(predicate<MethodCall>(
          (c) =>
              c.method == 'OneSignal#requestPermission' &&
              (c.arguments as Map)['fallbackToSettings'] == true,
        )),
      );
    });

    test('an observer is notified and stops firing once removed', () async {
      final sdk = OneSignalSdk();
      final seen = <String?>[];
      void listener(String? id) => seen.add(id);

      sdk.addSubscriptionObserver(listener);
      await fireSubscriptionChange('sub-42');
      expect(seen, ['sub-42']);

      sdk.removeSubscriptionObserver(listener);
      await fireSubscriptionChange('sub-43');
      expect(seen, ['sub-42'], reason: 'a removed observer must stay silent');
    });
  });

  group('OneSignalPushService over the concrete SDK', () {
    test('a missing push plugin is swallowed and the service keeps working',
        () async {
      permissionFails = true;
      final service = OneSignalPushService(appId: 'app-1');

      await service.init();
      await expectLater(service.requestPermission(), completes);

      expect(service.subscriptionId, isNull);
    });

    test('the service reports the id the host assigned', () async {
      hostSubscriptionId = 'sub-777';
      final service = OneSignalPushService(appId: 'app-1');

      await service.init();

      expect(service.subscriptionId, 'sub-777');
    });
  });
}
