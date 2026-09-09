import 'dart:convert';
import 'dart:io';

import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/data/local_address_repository.dart';
import 'package:al_batal_elite/features/addresses/domain/address.dart';
import 'package:al_batal_elite/features/payments/data/paymob_payment_service.dart';
import 'package:al_batal_elite/features/payments/domain/paymob_url_guard.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/memory_secure_store.dart';

/// Residual-hardening slice (P2 uploads + R4 navigation + R5 parsing):
/// fail-closed avatar validation, fail-soft cache parsing, and the URL
/// re-check the WebView's `onUrlChange` delegates to.
void main() {
  group('avatar upload validation (fail-closed)', () {
    test('rejects svg extension', () {
      final svc = StorageService();
      expect(
        svc.uploadAvatar(File('avatar.svg'), 'user-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a filename with no extension', () {
      final svc = StorageService();
      expect(
        svc.uploadAvatar(File('avatar'), 'user-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects traversal in the user segment', () {
      final svc = StorageService();
      expect(
        svc.uploadAvatar(File('ok.png'), '../../etc'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects oversize files before any upload', () async {
      final dir = await Directory.systemTemp.createTemp('avatar-hardening');
      try {
        final file = File('${dir.path}/big.jpg');
        await file.writeAsBytes(
          List<int>.filled(StorageService.avatarMaxBytes + 1, 0),
        );
        final svc = StorageService();
        await expectLater(
          svc.uploadAvatar(file, 'user-1'),
          throwsA(isA<ArgumentError>()),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('cache parsing (fail-soft, never throws)', () {
    test('readCart returns empty on corrupt JSON', () async {
      SharedPreferences.setMockInitialValues({
        'storefront_cart_lines_v1': 'not-json{{{',
      });
      final prefs = await SharedPreferences.getInstance();
      final persistence = LocalStorefrontPersistence(
        prefs,
        secureStore: MemorySecureStore(),
      );
      expect(await persistence.readCart((_) => null), isEmpty);
    });

    test('readWishlist returns empty on truncated JSON', () async {
      SharedPreferences.setMockInitialValues({
        'storefront_wishlist_ids_v1': '["a","b"',
      });
      final prefs = await SharedPreferences.getInstance();
      final persistence = LocalStorefrontPersistence(
        prefs,
        secureStore: MemorySecureStore(),
      );
      expect(await persistence.readWishlist(), isEmpty);
    });

    test('readOrders returns empty on corrupt secure snapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final persistence = LocalStorefrontPersistence(
        prefs,
        secureStore: MemorySecureStore({
          'storefront_orders_v1': '{"orders":',
        }),
      );
      expect(await persistence.readOrders(), isEmpty);
    });

    test('OrderCodec.decode skips tampered entries without throwing', () {
      expect(
        OrderCodec.decode(const <Object?, Object?>{}),
        isNull,
      );
      expect(
        OrderCodec.decode(const <Object?, Object?>{
          'id': 'o1',
          'items': [],
          'status': 'bogus-status',
          'subtotal': 1,
          'shipping': 0,
          'total': 1,
          'placedAt': '2026-09-01T00:00:00Z',
          'paymentMethod': 'cod',
        }),
        isNull,
      );
      expect(
        OrderCodec.decode(const <Object?, Object?>{
          'id': 'o1',
          'items': [],
          'status': 'placed',
          'subtotal': 1,
          'shipping': 0,
          'total': 1,
          'placedAt': 'not-a-date',
          'paymentMethod': 'cod',
        }),
        isNull,
      );
      // Mistyped money/color fields degrade instead of throwing.
      expect(
        OrderCodec.decode(const <Object?, Object?>{
          'id': 'o1',
          'items': [
            {
              'product': {'id': 'p1'},
              'color': 42,
              'length': '1m',
              'quantity': 'many',
            },
          ],
          'status': 'placed',
          'subtotal': 'lots',
          'shipping': 'free',
          'total': 'lots',
          'placedAt': '2026-09-01T00:00:00Z',
          'paymentMethod': 'cod',
        })?.items,
        isEmpty,
      );
    });

    test('address book skips malformed entries, empties on corrupt JSON',
        () async {
      SharedPreferences.setMockInitialValues({
        'saved_addresses_v1': jsonEncode([
          {
            'id': 'a1',
            'recipient': 'Layla',
            'line': '1 Nile St',
            'city': 'Cairo',
            'country': 'EG',
            'isDefault': true,
          },
          'junk-entry',
          {'nope': 1},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo =
          LocalAddressRepository(prefs, secureStore: MemorySecureStore());

      final result = await repo.read();
      expect(result, isA<Success<List<Address>>>());
      expect((result as Success<List<Address>>).value, hasLength(1));

      SharedPreferences.setMockInitialValues({
        'saved_addresses_v1': '[[[corrupt',
      });
      final prefs2 = await SharedPreferences.getInstance();
      final repo2 =
          LocalAddressRepository(prefs2, secureStore: MemorySecureStore());
      final corrupt = await repo2.read();
      expect(corrupt, isA<Success<List<Address>>>());
      expect((corrupt as Success<List<Address>>).value, isEmpty);
    });
  });

  group('WebView URL re-check (onUrlChange guard)', () {
    test('rejects javascript: pseudo-URLs', () {
      expect(
        PaymobUrlGuard.isSafeWebViewNavigationTarget('javascript:alert(1)'),
        isFalse,
      );
    });

    test('rejects an http downgrade redirect', () {
      expect(
        PaymobUrlGuard.isSafeWebViewNavigationTarget(
          'http://accept.paymob.com/iframes/1?payment_token=x',
        ),
        isFalse,
      );
    });

    test('rejects a suffix-spoof host', () {
      expect(
        PaymobUrlGuard.isSafeWebViewNavigationTarget(
          'https://accept.paymob.com.evil.example.com/iframes/1',
        ),
        isFalse,
      );
    });

    test('accepts the genuine Paymob iframe target', () {
      expect(
        PaymobUrlGuard.isSafeWebViewNavigationTarget(
          'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=abc',
        ),
        isTrue,
      );
    });

    test('redact keeps redirect URLs log-safe', () {
      const url =
          'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=SECRET_TOKEN_VALUE';
      final redacted = PaymobUrlGuard.redact(url);
      expect(redacted, isNot(contains('SECRET_TOKEN_VALUE')));
    });
  });

  group('Paymob row parsing (fail-soft)', () {
    test('terminalResultForRow ignores mistyped rows without throwing', () {
      expect(
        PaymobPaymentService.terminalResultForRow(
          const <String, dynamic>{
            'status': 42,
            'transaction_id': ['x']
          },
        ),
        isNull,
      );
      expect(
        PaymobPaymentService.terminalResultForRow(const <String, dynamic>{}),
        isNull,
      );
    });
  });
}
