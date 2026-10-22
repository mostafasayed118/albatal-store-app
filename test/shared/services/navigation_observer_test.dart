import 'package:al_batal_elite/shared/services/navigation_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Route<void> route(String? name) => MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => const SizedBox.shrink(),
      );

  test('pop/replace/back-gesture events are logged without throwing', () {
    final observer = NavigationObserver();
    final pushed = route('pushed');
    final popped = route(null);
    final replacement = route('replacement');

    expect(() => observer.didPop(popped, pushed), returnsNormally);
    expect(
      () => observer.didReplace(newRoute: replacement, oldRoute: pushed),
      returnsNormally,
    );
    expect(
      () => observer.didReplace(newRoute: null, oldRoute: null),
      returnsNormally,
    );
    expect(
      () => observer.didStartUserGesture(pushed, null),
      returnsNormally,
    );
  });
}
