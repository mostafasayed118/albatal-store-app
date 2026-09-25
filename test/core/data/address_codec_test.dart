import 'package:al_batal_elite/core/data/address_codec.dart';
import 'package:al_batal_elite/core/entities/address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddressCodec', () {
    test('codec round-trips the 7-key persisted shape including phone', () {
      const shape = {
        'id': 'a1',
        'recipient': 'Layla',
        'line': '1 Nile St',
        'city': 'Cairo',
        'country': 'EG',
        'phone': '01012345678',
        'isDefault': true,
      };
      final addr = AddressCodec.fromJson(shape);
      expect(addr.phone, '01012345678');
      expect(AddressCodec.toJson(addr), shape);
    });

    test('a pre-phone legacy row decodes and re-encodes additively', () {
      // Rows persisted before phone shipped carry no `phone` key. The
      // decode degrades it to "no phone on file" (''); the re-encode
      // emits the key with that default — the persisted shape grows
      // additively and every decoder stays tolerant of the old shape.
      const legacy = {
        'id': 'a1',
        'recipient': 'Layla',
        'line': '1 Nile St',
        'city': 'Cairo',
        'country': 'EG',
        'isDefault': true,
      };
      final addr = AddressCodec.fromJson(legacy);
      expect(addr.phone, isEmpty);
      expect(AddressCodec.toJson(addr), {...legacy, 'phone': ''});
    });

    test('fromJson defaults a missing isDefault to false', () {
      const legacy = {
        'id': 'a1',
        'recipient': 'Layla',
        'line': '1 Nile St',
        'city': 'Cairo',
        'country': 'EG',
      };
      final addr = AddressCodec.fromJson(legacy);
      expect(addr.isDefault, isFalse);
      expect(
        AddressCodec.toJson(addr),
        {...legacy, 'phone': '', 'isDefault': false},
      );
    });

    test('toSnapshotJson emits the 6-key checkout snapshot (legacy 5 + phone)',
        () {
      const address = Address(
        id: 'addr-1',
        recipient: 'Test User',
        line: '123 Test St',
        city: 'Cairo',
        country: 'Egypt',
        phone: '01012345678',
        isDefault: true,
      );
      expect(
        AddressCodec.toSnapshotJson(address),
        const {
          'id': 'addr-1',
          'recipient': 'Test User',
          'line': '123 Test St',
          'city': 'Cairo',
          'country': 'Egypt',
          'phone': '01012345678',
        },
      );
    });

    test('toSnapshotJson carries an empty phone for phone-less rows', () {
      // Legacy rows still decode; the checkout gate blocks them until a
      // phone is supplied before the server receives the snapshot.
      const address = Address(
        id: 'addr-1',
        recipient: 'Test User',
        line: '123 Test St',
        city: 'Cairo',
        country: 'Egypt',
      );
      expect(AddressCodec.toSnapshotJson(address)['phone'], '');
    });

    test('fromOrderJson round-trips a well-formed legacy order address', () {
      const legacy = {
        'id': 'a1',
        'recipient': 'Layla',
        'line': '1 Nile St',
        'city': 'Cairo',
        'country': 'EG',
        'isDefault': true,
      };
      final addr = AddressCodec.fromOrderJson(legacy);
      expect(addr, AddressCodec.fromJson(legacy));
      expect(AddressCodec.toJson(addr), {...legacy, 'phone': ''});
    });

    test('fromOrderJson keeps the legacy tolerant country fallback', () {
      final addr = AddressCodec.fromOrderJson(const {
        'id': 'a1',
        'recipient': 'Layla',
        'line': '1 Nile St',
        'city': 'Cairo',
      });
      expect(addr.country, isEmpty);
      expect(addr.phone, isEmpty);
      expect(addr.isDefault, isFalse);
    });

    test('fromOrderJson restores a snapshot that carries a phone', () {
      final addr = AddressCodec.fromOrderJson(const {
        'id': 'a1',
        'recipient': 'Layla',
        'line': '1 Nile St',
        'city': 'Cairo',
        'country': 'EG',
        'phone': '01112345678',
      });
      expect(addr.phone, '01112345678');
    });
  });
}
