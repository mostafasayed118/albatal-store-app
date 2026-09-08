import 'package:al_batal_elite/core/data/address_codec.dart';
import 'package:al_batal_elite/core/entities/address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddressCodec', () {
    test('codec round-trips the legacy persisted shape', () {
      const legacy = {
        'id': 'a1',
        'recipient': 'Layla',
        'line': '1 Nile St',
        'city': 'Cairo',
        'country': 'EG',
        'isDefault': true,
      };
      final addr = AddressCodec.fromJson(legacy);
      expect(AddressCodec.toJson(addr), legacy);
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
        {...legacy, 'isDefault': false},
      );
    });

    test('toSnapshotJson emits the legacy checkout snapshot shape', () {
      const address = Address(
        id: 'addr-1',
        recipient: 'Test User',
        line: '123 Test St',
        city: 'Cairo',
        country: 'Egypt',
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
        },
      );
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
      expect(AddressCodec.toJson(addr), legacy);
    });

    test('fromOrderJson keeps the legacy tolerant country fallback', () {
      final addr = AddressCodec.fromOrderJson(const {
        'id': 'a1',
        'recipient': 'Layla',
        'line': '1 Nile St',
        'city': 'Cairo',
      });
      expect(addr.country, isEmpty);
      expect(addr.isDefault, isFalse);
    });
  });
}
