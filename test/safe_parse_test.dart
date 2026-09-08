import 'package:al_batal_elite/core/utils/safe_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeString (audit P5)', () {
    test('returns the value when present and a String', () {
      expect(safeString({'name': 'Silk'}, 'name'), 'Silk');
    });

    test('falls back on missing keys, null maps, and wrong types', () {
      expect(safeString({}, 'name'), '');
      expect(safeString(null, 'name'), '');
      expect(safeString({'name': 42}, 'name'), '');
      expect(safeString({'name': null}, 'name'), '');
    });

    test('honors an explicit fallback', () {
      expect(safeString({}, 'status', fallback: 'pending'), 'pending');
    });
  });

  group('safeInt (audit P5)', () {
    test('returns ints and coerces other nums', () {
      expect(safeInt({'pct': 15}, 'pct'), 15);
      expect(safeInt({'pct': 15.0}, 'pct'), 15);
    });

    test('falls back on missing keys and non-nums', () {
      expect(safeInt({}, 'pct'), 0);
      expect(safeInt({'pct': 'half-off'}, 'pct'), 0);
      expect(safeInt({'pct': 'half-off'}, 'pct', fallback: 15), 15);
    });
  });

  group('safeBool (audit P5)', () {
    test('passes bools through and falls back otherwise', () {
      expect(safeBool({'v': true}, 'v'), isTrue);
      expect(safeBool({'v': false}, 'v'), isFalse);
      expect(safeBool({}, 'v'), isFalse);
      expect(safeBool({'v': 'yes'}, 'v', fallback: true), isTrue);
    });
  });

  group('safeMap (audit P5)', () {
    test('passes typed maps through and normalizes key types', () {
      final typed = {'a': 1};
      expect(identical(safeMap(typed), typed), isTrue);
      expect(safeMap({1: 'x'}), {'1': 'x'});
    });

    test('returns an empty map for non-maps', () {
      expect(safeMap(null), isEmpty);
      expect(safeMap('nope'), isEmpty);
      expect(safeMap([1, 2]), isEmpty);
    });
  });
}
