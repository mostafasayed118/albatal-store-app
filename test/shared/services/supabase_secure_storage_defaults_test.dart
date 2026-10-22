import 'package:al_batal_elite/shared/services/supabase_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_secure_store.dart';

void main() {
  test('both adapters build with the default secure store', () {
    final session = SecureSessionStorage(persistSessionKey: 'sb-auth-token');
    final pkce = SecureGotrueStorage();

    expect(session.persistSessionKey, 'sb-auth-token');
    expect(pkce, isNotNull);
  });

  test('a failed session persist is logged and swallowed', () async {
    final storage = SecureSessionStorage(
      persistSessionKey: 'sb-auth-token',
      secureStore: ThrowingSecureStore(),
    );

    await expectLater(storage.persistSession('{"token":"x"}'), completes);
  });
}
