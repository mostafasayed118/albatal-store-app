import 'package:al_batal_elite/shared/components/push_verification_listener.dart';
import 'package:al_batal_elite/shared/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake port: the OneSignal SDK never runs in tests.
final class _FakePushService implements PushService {
  _FakePushService(this.id);

  final String? id;
  void Function(String? id)? observer;
  bool permissionRequested = false;
  bool removed = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> login(String userId) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPermission() async {
    permissionRequested = true;
  }

  @override
  String? get subscriptionId => id;

  @override
  Future<void> addSubscriptionObserver(
      void Function(String? id) listener) async {
    observer = listener;
  }

  @override
  void removeSubscriptionObserver(void Function(String? id) listener) {
    removed = true;
  }
}

void main() {
  Widget harness(PushService push, GlobalKey<NavigatorState> key) =>
      MaterialApp(
        navigatorKey: key,
        home: PushVerificationListener(
          navigatorKey: key,
          pushService: push,
          child: const Scaffold(body: Text('app')),
        ),
      );

  testWidgets('a server-assigned subscription id shows the one-time dialog',
      (tester) async {
    final push = _FakePushService('sub-123');
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(harness(push, key));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Your OneSignal SDK integration is complete!'),
      findsOneWidget,
    );
    expect(push.permissionRequested, isFalse);

    await tester.tap(find.text('Got it'));
    await tester.pump();

    expect(push.permissionRequested, isTrue);
  });

  testWidgets('a local placeholder id is not treated as registered',
      (tester) async {
    final push = _FakePushService('local-placeholder');
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(harness(push, key));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Your OneSignal SDK integration is complete!'),
      findsNothing,
    );
  });

  testWidgets('a late subscription change still surfaces the dialog',
      (tester) async {
    final push = _FakePushService(null);
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(harness(push, key));
    await tester.pump();

    expect(
        find.text('Your OneSignal SDK integration is complete!'), findsNothing);

    // The SDK assigns the real id after the observer is attached.
    push.observer?.call('sub-456');
    await tester.pumpAndSettle();

    expect(
      find.text('Your OneSignal SDK integration is complete!'),
      findsOneWidget,
    );
  });

  testWidgets('the observer is released with the widget', (tester) async {
    final push = _FakePushService('sub-789');
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(harness(push, key));
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    await tester.pump();

    expect(push.removed, isTrue);
  });
}
