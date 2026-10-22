import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the `FlutterImageCompressor` implementation itself (the
/// existing `image_compressor_test.dart` only pins the pure threshold
/// helper and the interface contract). The platform seam is replaced with
/// a fake so the compress / keep-original / fail-open branches run
/// without a device plugin.
final class _FakeCompressPlatform extends Fake
    implements FlutterImageCompressPlatform {
  int calls = 0;
  Exception? throwOnCompress;
  int Function(Uint8List input)? outputLength;
  int? seenMinWidth;
  int? seenMinHeight;
  int? seenQuality;
  CompressFormat? seenFormat;

  @override
  FlutterImageCompressValidator get validator =>
      FlutterImageCompressValidator(const MethodChannel('test-compress'));

  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async {
    calls++;
    seenMinWidth = minWidth;
    seenMinHeight = minHeight;
    seenQuality = quality;
    seenFormat = format;
    final error = throwOnCompress;
    if (error != null) throw error;
    final length = outputLength?.call(image) ?? image.length ~/ 2;
    return Uint8List.fromList(List.filled(length, 3));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCompressPlatform platform;
  late FlutterImageCompressPlatform original;

  setUp(() {
    platform = _FakeCompressPlatform();
    original = FlutterImageCompressPlatform.instance;
    FlutterImageCompressPlatform.instance = platform;
  });

  tearDown(() {
    FlutterImageCompressPlatform.instance = original;
  });

  Uint8List largeInput() =>
      Uint8List.fromList(List.filled(kCompressionThresholdBytes + 1, 9));

  test('small images short-circuit before the platform call', () async {
    final input = Uint8List.fromList(List.filled(32, 1));

    final out = await const FlutterImageCompressor().compress(input);

    expect(out, same(input));
    expect(platform.calls, 0);
  });

  test('large images are re-encoded with the §4 upload settings', () async {
    final input = largeInput();

    final out = await const FlutterImageCompressor().compress(input);

    expect(platform.calls, 1);
    expect(platform.seenMinWidth, kMaxUploadDimension);
    expect(platform.seenMinHeight, kMaxUploadDimension);
    expect(platform.seenQuality, 82);
    expect(platform.seenFormat, CompressFormat.jpeg);
    expect(out.length, input.length ~/ 2);
  });

  test('a pathologically larger re-encode is rejected', () async {
    final input = largeInput();
    platform.outputLength = (bytes) => bytes.length + 10;

    final out = await const FlutterImageCompressor().compress(input);

    expect(out, same(input));
  });

  test('platform exceptions fail open with the original bytes', () async {
    final input = largeInput();
    platform.throwOnCompress = Exception('decoder unavailable');

    final out = await const FlutterImageCompressor().compress(input);

    expect(out, same(input));
    expect(platform.calls, 1);
  });
}
