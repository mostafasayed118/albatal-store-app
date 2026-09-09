import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'logger.dart';

/// Two-layer online signal: cheap interface flap + debounced reachability truth.
///
/// `connectivity_plus` alone reports hotel-WiFi-with-no-internet as online,
/// so every interface change is confirmed with
/// `internet_connection_checker_plus` before emitting — except
/// [ConnectivityResult.none], which is offline without a probe round-trip.
///
/// Lives in `shared/services` (app-scoped, GetIt lazy singleton) and never
/// touches presentation state: callers subscribe to [isOnline] or read
/// [current]. The injected [InternetConnection] singleton is never disposed
/// here — only this gate's own subscriptions are cancelled in [dispose].
class ConnectivityGate {
  ConnectivityGate({Connectivity? connectivity, InternetConnection? checker})
      : _connectivity = connectivity ?? Connectivity(),
        _checker = checker ?? InternetConnection();

  final Connectivity _connectivity;
  final InternetConnection _checker;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _ifaceSub;
  StreamSubscription<InternetStatus>? _reachSub;
  bool _current = true;
  bool _started = false;

  /// Last emitted value. Optimistically online until [start] seeds the truth.
  bool get current => _current;

  /// Distinct online values only — repeats are swallowed in [_emit].
  Stream<bool> get isOnline => _controller.stream;

  /// Seeds from the reachability probe, then listens to both layers.
  /// Second calls are a no-op (guarded by [_started]).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _emit(await _checker.hasInternetAccess);
    _ifaceSub = _connectivity.onConnectivityChanged.listen((results) async {
      if (results.contains(ConnectivityResult.none)) {
        _emit(false);
      } else {
        _emit(await _checker.hasInternetAccess);
      }
    });
    _reachSub = _checker.onStatusChange.listen((status) {
      _emit(status == InternetStatus.connected);
    });
  }

  /// Manual re-probe for Retry taps. Emits only when the truth changed.
  Future<void> recheck() async => _emit(await _checker.hasInternetAccess);

  void _emit(bool online) {
    if (online == _current) return;
    _current = online;
    if (!_controller.isClosed) _controller.add(online);
    Log.i(online ? 'Back online' : 'Went offline',
        category: LogCategory.network);
  }

  /// Cancels this gate's subscriptions. Never disposes the shared
  /// [InternetConnection] singleton (v3 contract).
  Future<void> dispose() async {
    await _ifaceSub?.cancel();
    await _reachSub?.cancel();
    _ifaceSub = null;
    _reachSub = null;
    await _controller.close();
    _started = false;
  }
}
