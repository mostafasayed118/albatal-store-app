import 'dart:typed_data';

import 'package:al_batal_elite/features/payments/presentation/widgets/instapay_proof_picker.dart';
import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../../helpers/proof_image_picker_platform_fake.dart';

class _FakeCompressor implements ImageCompressor {
  _FakeCompressor({this.output, this.error});

  Uint8List? output;
  Object? error;
  int calls = 0;
  Uint8List? lastInput;

  @override
  Future<Uint8List> compress(Uint8List bytes) async {
    calls++;
    lastInput = bytes;
    final failure = error;
    if (failure != null) throw failure;
    return output ?? bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ImagePickerPlatform original;
  late ProofImagePickerPlatformFake platform;
  late List<String> errors;

  setUp(() {
    original = ImagePickerPlatform.instance;
    platform = ProofImagePickerPlatformFake();
    ImagePickerPlatform.instance = platform;
    errors = [];
  });

  tearDown(() {
    ImagePickerPlatform.instance = original;
  });

  Future<ProofScreenshot?> pick({
    ImageCompressor? compressor,
    int maxBytes = 1024,
    Set<String> allowed = const {'png', 'jpg', 'jpeg', 'webp'},
  }) =>
      pickInstapayProofScreenshot(
        picker: ImagePicker(),
        compressor: compressor,
        maxBytes: maxBytes,
        allowedExtensions: allowed,
        emptyError: 'empty',
        tooLargeError: 'too-large',
        typeNotAllowedError: 'wrong-type',
        onError: errors.add,
      );

  test('cancelled pick returns null without reporting an error', () async {
    final result = await pick();

    expect(result, isNull);
    expect(errors, isEmpty);
    expect(platform.calls, 1);
    expect(platform.lastSource, ImageSource.gallery);
    expect(platform.lastOptions?.maxWidth, 1600);
    expect(platform.lastOptions?.maxHeight, 1600);
    expect(platform.lastOptions?.imageQuality, 80);
  });

  test('empty file reports emptyError', () async {
    platform.file = XFile.fromData(Uint8List(0), path: 'proof.png');

    final result = await pick();

    expect(result, isNull);
    expect(errors, ['empty']);
  });

  test('valid png is returned with lowercased extension and file name',
      () async {
    platform.file = XFile.fromData(
      Uint8List.fromList(const [1, 2, 3]),
      path: 'Proof.PNG',
    );

    final result = await pick();

    expect(result, isNotNull);
    expect(result!.bytes, const [1, 2, 3]);
    expect(result.ext, 'png');
    expect(result.fileName, 'Proof.PNG');
    expect(errors, isEmpty);
  });

  test('a name without a dot defaults to jpg', () async {
    platform.file = XFile.fromData(
      Uint8List.fromList(const [4, 5]),
      path: 'proof',
    );

    final result = await pick();

    expect(result!.ext, 'jpg');
  });

  test('compressor output replaces the raw bytes', () async {
    platform.file = XFile.fromData(
      Uint8List.fromList(const [1, 2, 3]),
      path: 'proof.jpg',
    );
    final compressor = _FakeCompressor(
      output: Uint8List.fromList(const [9, 9]),
    );

    final result = await pick(compressor: compressor);

    expect(compressor.calls, 1);
    expect(compressor.lastInput, const [1, 2, 3]);
    expect(result!.bytes, const [9, 9]);
  });

  test('oversized file reports tooLargeError after compression', () async {
    platform.file = XFile.fromData(
      Uint8List.fromList(const [1, 2, 3]),
      path: 'proof.png',
    );

    final result = await pick(maxBytes: 2);

    expect(result, isNull);
    expect(errors, ['too-large']);
  });

  test('non-allowlisted extension reports typeNotAllowedError', () async {
    platform.file = XFile.fromData(
      Uint8List.fromList(const [1]),
      path: 'proof.heic',
    );

    final result = await pick();

    expect(result, isNull);
    expect(errors, ['wrong-type']);
  });

  test('picker exception is caught and reported as emptyError', () async {
    platform.error = Exception('MissingPluginException');

    final result = await pick();

    expect(result, isNull);
    expect(errors, ['empty']);
  });

  test('compressor exception is caught and reported as emptyError', () async {
    platform.file = XFile.fromData(
      Uint8List.fromList(const [1]),
      path: 'proof.png',
    );
    final compressor = _FakeCompressor(error: Exception('codec failed'));

    final result = await pick(compressor: compressor);

    expect(result, isNull);
    expect(errors, ['empty']);
  });
}
