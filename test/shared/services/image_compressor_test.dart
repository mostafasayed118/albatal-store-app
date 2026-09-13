import 'dart:typed_data';

import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldCompress (§4 threshold gate)', () {
    test('keeps small images untouched', () {
      expect(shouldCompress(0), isFalse);
      expect(shouldCompress(1024), isFalse);
      expect(shouldCompress(kCompressionThresholdBytes), isFalse);
    });

    test('flags images over the threshold', () {
      expect(shouldCompress(kCompressionThresholdBytes + 1), isTrue);
      expect(shouldCompress(5 * 1024 * 1024), isTrue);
    });
  });

  group('ImageCompressor contract', () {
    test('no-op compressor returns input bytes (fake contract check)',
        () async {
      final bytes = Uint8List.fromList(List.filled(10, 7));
      final result = await _PassthroughCompressor().compress(bytes);
      expect(result, same(bytes));
    });
  });
}

/// Smallest fail-open fake used to pin the interface contract; the
/// plugin path itself is untestable without a platform channel and is
/// exercised on-device instead.
final class _PassthroughCompressor implements ImageCompressor {
  @override
  Future<Uint8List> compress(Uint8List bytes) async => bytes;
}
