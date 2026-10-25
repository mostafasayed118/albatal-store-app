import 'package:al_batal_elite/shared/services/secure_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  test('read/write/delete forward the key, payload and options', () async {
    final storage = _MockSecureStorage();
    when(() => storage.read(
          key: 'session',
          iOptions: FlutterSecureStore.iosOptions,
          aOptions: FlutterSecureStore.androidOptions,
        )).thenAnswer((_) async => 'secret-value');
    when(() => storage.write(
          key: 'session',
          value: 'secret-value',
          iOptions: FlutterSecureStore.iosOptions,
          aOptions: FlutterSecureStore.androidOptions,
        )).thenAnswer((_) async {});
    when(() => storage.delete(
          key: 'session',
          iOptions: FlutterSecureStore.iosOptions,
          aOptions: FlutterSecureStore.androidOptions,
        )).thenAnswer((_) async {});

    final store = FlutterSecureStore(storage: storage);

    expect(await store.read('session'), 'secret-value');
    await store.write('session', 'secret-value');
    await store.delete('session');

    verify(() => storage.read(
          key: 'session',
          iOptions: FlutterSecureStore.iosOptions,
          aOptions: FlutterSecureStore.androidOptions,
        )).called(1);
    verify(() => storage.write(
          key: 'session',
          value: 'secret-value',
          iOptions: FlutterSecureStore.iosOptions,
          aOptions: FlutterSecureStore.androidOptions,
        )).called(1);
    verify(() => storage.delete(
          key: 'session',
          iOptions: FlutterSecureStore.iosOptions,
          aOptions: FlutterSecureStore.androidOptions,
        )).called(1);
  });
}
