import 'dart:async';

import 'package:al_batal_elite/shared/services/connectivity_gate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _MockChecker extends Mock implements InternetConnection {}

/// Flushes one event-loop turn so sync-controller events + stubbed
/// futures propagate deterministically (no timers involved).
Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  late _MockConnectivity connectivity;
  late _MockChecker checker;
  late StreamController<List<ConnectivityResult>> iface;
  late StreamController<InternetStatus> reach;
  ConnectivityGate? gate;

  setUp(() {
    connectivity = _MockConnectivity();
    checker = _MockChecker();
    iface = StreamController<List<ConnectivityResult>>(sync: true);
    reach = StreamController<InternetStatus>(sync: true);
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => iface.stream);
    when(() => checker.onStatusChange).thenAnswer((_) => reach.stream);
  });

  tearDown(() async {
    await gate?.dispose();
    await iface.close();
    await reach.close();
  });

  Future<List<bool>> collectEvents(ConnectivityGate gate) async {
    final events = <bool>[];
    gate.isOnline.listen(events.add);
    return events;
  }

  test('seeds online when the reachability probe succeeds', () async {
    when(() => checker.hasInternetAccess).thenAnswer((_) async => true);
    gate = ConnectivityGate(connectivity: connectivity, checker: checker);
    final events = await collectEvents(gate!);

    await gate!.start();
    await _pump();

    expect(gate!.current, isTrue);
    expect(events, isEmpty); // seed == default: no duplicate emit
  });

  test('seeds offline when the reachability probe fails', () async {
    when(() => checker.hasInternetAccess).thenAnswer((_) async => false);
    gate = ConnectivityGate(connectivity: connectivity, checker: checker);
    final events = await collectEvents(gate!);

    await gate!.start();
    await _pump();

    expect(gate!.current, isFalse);
    expect(events, [false]);
  });

  test('interface none emits offline without a second probe', () async {
    when(() => checker.hasInternetAccess).thenAnswer((_) async => true);
    gate = ConnectivityGate(connectivity: connectivity, checker: checker);
    final events = await collectEvents(gate!);
    await gate!.start();
    await _pump();
    clearInteractions(checker);

    iface.add(const [ConnectivityResult.none]);
    await _pump();

    expect(gate!.current, isFalse);
    expect(events, [false]);
    verifyNever(() => checker.hasInternetAccess);
  });

  test('wifi with failing probe stays online=false and emits once', () async {
    when(() => checker.hasInternetAccess).thenAnswer((_) async => false);
    gate = ConnectivityGate(connectivity: connectivity, checker: checker);
    final events = await collectEvents(gate!);
    await gate!.start(); // seeds false
    await _pump();

    iface.add(const [ConnectivityResult.wifi]);
    await _pump();

    expect(gate!.current, isFalse);
    expect(events, [false]); // distinct: no second emit
  });

  test('hotel-wifi recovery: probe success after outage emits true', () async {
    var online = false;
    when(() => checker.hasInternetAccess).thenAnswer((_) async => online);
    gate = ConnectivityGate(connectivity: connectivity, checker: checker);
    final events = await collectEvents(gate!);
    await gate!.start();
    await _pump();
    expect(events, [false]);

    online = true;
    reach.add(InternetStatus.connected);
    await _pump();

    expect(gate!.current, isTrue);
    expect(events, [false, true]);
  });

  test('second start is a no-op (single seed, single subscription)', () async {
    when(() => checker.hasInternetAccess).thenAnswer((_) async => true);
    gate = ConnectivityGate(connectivity: connectivity, checker: checker);
    await gate!.start();
    await gate!.start();
    await _pump();

    verify(() => checker.hasInternetAccess).called(1);
    verify(() => connectivity.onConnectivityChanged).called(1);
  });

  test('recheck re-probes and emits only on change', () async {
    var online = false;
    when(() => checker.hasInternetAccess).thenAnswer((_) async => online);
    gate = ConnectivityGate(connectivity: connectivity, checker: checker);
    final events = await collectEvents(gate!);
    await gate!.start();
    await _pump();
    expect(events, [false]);

    online = true;
    await gate!.recheck();
    await _pump();

    expect(gate!.current, isTrue);
    expect(events, [false, true]);

    await gate!.recheck(); // no change: no duplicate emit
    await _pump();
    expect(events, [false, true]);
  });
}
