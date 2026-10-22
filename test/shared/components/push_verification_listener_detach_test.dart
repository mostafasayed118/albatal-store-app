import 'dart:async';

import 'package:al_batal_elite/shared/components/push_verification_listener.dart';
import 'package:al_batal_elite/shared/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Push double whose observer registration stays pending, so the widget
/// can be unmounted before the attach completes.
final class _PendingAttachPushService implements PushService {
  final attach = Completer<void>();
  final removals = <void Function(String?)>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> login(String userId) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  String? get subscriptionId => null;

  @override
  Future<void> addSubscriptionObserver(void Function(String? id) listener) =>
      attach.future;

  @override
  void removeSubscriptionObserver(void Function(String? id) listener) {
    removals.add(listener);
  }
}

void main() {
  testWidgets(
      'an unmounted widget releases the observer it never finished attaching',
      (tester) async {
    final push = _PendingAttachPushService();
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      home: PushVerificationListener(
        navigatorKey: key,
        pushService: push,
        child: const Scaffold(body: Text('app')),
      ),
    ));
    await tester.pump();

    // Unmount before the observer registration resolves.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    await tester.pump();
    expect(push.removals, hasLength(1), reason: 'dispose releases it');

    push.attach.complete();
    await tester.pump();

    expect(push.removals, hasLength(2),
        reason: 'the pending attach must release the observer it lost');
  });
}
