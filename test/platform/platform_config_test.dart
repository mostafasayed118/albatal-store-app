import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the platform configuration that `flutter analyze` and the widget
/// tests cannot see, and that only fails in a RELEASE build / on a real
/// device.
///
/// Root causes this locks down:
///   * `flutter build apk --release` merges ONLY `android/app/src/main`
///     (plus plugin library manifests). INTERNET lived in the `debug` and
///     `profile` manifests, so release APKs shipped with no network
///     permission and every Supabase/Paymob/Storage call failed. Nothing in
///     the Dart layer could ever detect that, and the release build was
///     already broken for an unrelated reason, so it went unnoticed.
///   * `local_auth` requires the host activity to be a `FragmentActivity`
///     and replies `NOT_FRAGMENT_ACTIVITY` for anything else, which silently
///     turned the biometric app lock into a no-op.
///   * `Info.plist` had `CFBundleURLTypes` OUTSIDE the root `<dict>`, which
///     is not a valid plist and left the `albatal://` scheme unregistered.
void main() {
  group('Android manifest', () {
    File manifest() => File('android/app/src/main/AndroidManifest.xml');

    test('declares INTERNET in the main source set (release builds)', () {
      final xml = manifest().readAsStringSync();
      expect(
        xml.contains('android.permission.INTERNET'),
        isTrue,
        reason: 'INTERNET must be in src/main, not only in the debug/profile '
            'manifests: `flutter build apk --release` does not merge those.',
      );
    });

    test('declares the permissions the enabled features need', () {
      final xml = manifest().readAsStringSync();
      for (final permission in const [
        'android.permission.ACCESS_NETWORK_STATE', // connectivity gate
        'android.permission.POST_NOTIFICATIONS', // local order notifications
        'android.permission.USE_BIOMETRIC', // biometric app lock
      ]) {
        expect(xml.contains(permission), isTrue,
            reason: '$permission must be declared explicitly.');
      }
    });

    test('debug-only source sets are not the only INTERNET declaration', () {
      // Documents the exact failure mode: the debug manifest does declare it,
      // which is why debug builds appeared healthy.
      final debug = File('android/app/src/debug/AndroidManifest.xml');
      expect(debug.readAsStringSync().contains('android.permission.INTERNET'),
          isTrue);
      expect(manifest().readAsStringSync().contains('INTERNET'), isTrue);
    });
  });

  group('MainActivity', () {
    test('extends FlutterFragmentActivity (local_auth requirement)', () {
      final source = File(
        'android/app/src/main/kotlin/com/albatal/elite/MainActivity.kt',
      ).readAsStringSync();
      expect(
        source.contains('FlutterFragmentActivity'),
        isTrue,
        reason: 'local_auth returns NOT_FRAGMENT_ACTIVITY for a plain '
            'FlutterActivity, disabling the app lock without any error.',
      );
      expect(
        RegExp(r'class MainActivity\s*:\s*FlutterFragmentActivity\(\)')
            .hasMatch(source),
        isTrue,
      );
    });
  });

  group('iOS Info.plist', () {
    String plist() => File('ios/Runner/Info.plist').readAsStringSync();

    test('is a single well-formed root dict', () {
      final xml = plist();
      // The DTD allows exactly one root object; `CFBundleURLTypes` used to be
      // emitted before the root <dict>, which made the file invalid.
      final dictOpen = xml.indexOf('<dict>');
      final firstKey = xml.indexOf('<key>');
      expect(firstKey > dictOpen, isTrue,
          reason: 'Every <key> must live inside the root <dict>; a key before '
              'the root dict means the plist is malformed.');
      expect(xml.trimRight().endsWith('</plist>'), isTrue);
    });

    test('registers the albatal URL scheme inside the root dict', () {
      final xml = plist();
      final schemeIndex = xml.indexOf('<string>albatal</string>');
      expect(schemeIndex, greaterThan(xml.indexOf('<dict>')));
      expect(xml.contains('CFBundleURLTypes'), isTrue);
    });

    test('declares NSFaceIDUsageDescription for the app lock', () {
      expect(
        plist().contains('NSFaceIDUsageDescription'),
        isTrue,
        reason: 'Without this key iOS refuses the Face ID prompt used by the '
            'biometric app lock.',
      );
    });
  });
}