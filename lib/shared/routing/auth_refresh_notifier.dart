import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';

final class AuthRefreshNotifier extends ChangeNotifier {
  // Assigned in the body (not an initializer list): the listen callback must
  // call the instance method `notifyListeners`, and `this` is not reachable
  // from initializer expressions (implicit_this_reference_in_initializer).
  AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
