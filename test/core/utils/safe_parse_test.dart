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

  group('optInt (audit finding #5)', () {
    test('returns ints and coerces other nums', () {
      expect(optInt({'n': 3}, 'n'), 3);
      expect(optInt({'n': 3.0}, 'n'), 3);
    });

    test('degrades to null on missing keys, null maps, and non-nums', () {
      expect(optInt({}, 'n'), isNull);
      expect(optInt(null, 'n'), isNull);
      expect(optInt({'n': null}, 'n'), isNull);
      expect(optInt({'n': '3'}, 'n'), isNull);
      expect(optInt({'n': true}, 'n'), isNull);
    });
  });

  group('optDouble (audit finding #5)', () {
    test('returns doubles and widens other nums', () {
      expect(optDouble({'x': 0.5}, 'x'), 0.5);
      expect(optDouble({'x': 2}, 'x'), 2.0);
    });

    test('degrades to null on missing keys and non-nums', () {
      expect(optDouble({}, 'x'), isNull);
      expect(optDouble(null, 'x'), isNull);
      expect(optDouble({'x': 'wide'}, 'x'), isNull);
      expect(optDouble({'x': true}, 'x'), isNull);
    });
  });

  group('optString (audit finding #5)', () {
    test('passes strings through', () {
      expect(optString({'s': 'silk'}, 's'), 'silk');
    });

    test('degrades to null on missing keys, null maps, and non-strings', () {
      expect(optString({}, 's'), isNull);
      expect(optString(null, 's'), isNull);
      expect(optString({'s': null}, 's'), isNull);
      expect(optString({'s': 42}, 's'), isNull);
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
