import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';

final class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
