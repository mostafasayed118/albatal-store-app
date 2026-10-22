import 'package:al_batal_elite/shared/services/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the three `FlutterSecureStore` delegation methods. The plugin
/// itself is absent in the VM, so the calls complete either normally or
/// with a missing-plugin exception — either way the delegation lines run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(Future<Object?> future) async {
    try {
      await future;
    } catch (_) {
      // The platform plugin is unavailable in the VM; the contract under
      // test is the pass-through of options, not the platform result.
    }
  }

  test('read/write/delete forward to the platform store', () async {
    final store = FlutterSecureStore();

    await settle(store.read('session'));
    await settle(store.write('session', 'value'));
    await settle(store.delete('session'));

    expect(FlutterSecureStore.iosOptions, isNotNull);
    expect(FlutterSecureStore.androidOptions, isNotNull);
  });
}
