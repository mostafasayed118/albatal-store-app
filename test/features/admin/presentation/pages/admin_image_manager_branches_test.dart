// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_image_manager_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_image_upload_flow.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:al_batal_elite/shared/components/app_image.dart';
import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../../helpers/proof_image_picker_platform_fake.dart';
import '../../../../helpers/test_only_admin_repository.dart';

class _FakeStorage extends StorageService {
  _FakeStorage() : super(client: null);

  @override
  String getProductImageUrl(String storagePath) =>
      'https://example.com/$storagePath';

  @override
  String getProductImageUrlForWidth(String storagePath, int width) =>
      'https://example.com/render/$width/$storagePath';

  @override
  Future<String> uploadProductImage(String productId, List<int> bytes,
          String fileName, String contentType) async =>
      'product-images/$productId/$fileName';

  @override
  Future<void> deleteProductImage(String storagePath) async {}
}

class _ShrinkCompressor implements ImageCompressor {
  @override
  Future<Uint8List> compress(Uint8List bytes) async =>
      Uint8List.sublistView(bytes, 0, 1024);
}

class _OversizeCompressor implements ImageCompressor {
  @override
  Future<Uint8List> compress(Uint8List bytes) async =>
      Uint8List(maxUploadImageBytes + 1);
}

/// [XFile.fromData] derives `name` from a (empty) path on the IO platform,
/// so the upload flow's extension check needs a named subclass instead.
class _NamedXFile extends XFile {
  _NamedXFile(this._name, this._bytes) : super('');

  final String _name;
  final Uint8List _bytes;

  @override
  String get name => _name;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;
}

void main() {
  late TestOnlyAdminRepository repo;
  late _FakeStorage storage;
  late ImagePickerPlatform originalPlatform;

  setUp(() {
    repo = TestOnlyAdminRepository();
    storage = _FakeStorage();
    originalPlatform = ImagePickerPlatform.instance;
  });

  tearDown(() {
    ImagePickerPlatform.instance = originalPlatform;
  });

  Widget harness({
    ProductImagePicker? pickImage,
    ImageCompressor? compressor,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminImageManagerPage(
          productId: 'pid',
          repository: repo,
          storage: storage,
          pickImage: pickImage ?? defaultProductImagePick,
          imageCompressor: compressor,
        ),
      );

  XFile fileOf(String name, {int size = 2048}) => _NamedXFile(
        name,
        Uint8List.fromList(List.filled(size, 1)),
      );

  test('the default picker asks the gallery for a bounded 80-quality image',
      () async {
    final platform = ProofImagePickerPlatformFake(
      file: _NamedXFile('picked.jpg', Uint8List(4)),
    );
    ImagePickerPlatform.instance = platform;

    final picked = await defaultProductImagePick(ImageSource.gallery);

    expect(picked, isNotNull);
    expect(platform.calls, 1);
    expect(platform.lastSource, ImageSource.gallery);
    expect(platform.lastOptions?.maxWidth, kMaxUploadDimension.toDouble());
    expect(platform.lastOptions?.maxHeight, kMaxUploadDimension.toDouble());
    expect(platform.lastOptions?.imageQuality, 80);
  });

  testWidgets('cancelling the delete dialog leaves the gallery untouched',
      (tester) async {
    repo.imagePathsResult = const Success(<String>['product-images/pid/a.jpg']);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.lastSavedImages, isNull);
    expect(find.byType(AppImage), findsOneWidget);
  });

  testWidgets('a failed gallery save surfaces the repository error',
      (tester) async {
    repo.imagePathsResult = const Success(<String>['product-images/pid/a.jpg']);
    repo.setImagesResult = const Failure(AppError('image save failed'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('image save failed'), findsOneWidget);
    expect(find.byType(AppImage), findsOneWidget,
        reason: 'the page must not adopt a path list the repository rejected');
  });

  testWidgets('an empty picked file is rejected with its own copy',
      (tester) async {
    await tester
        .pumpWidget(harness(pickImage: (_) async => fileOf('e.jpg', size: 0)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Selected file is empty.'), findsOneWidget);
    expect(repo.lastSavedImages, isNull);
  });

  testWidgets('an unsupported extension is rejected after compression',
      (tester) async {
    await tester.pumpWidget(harness(
      pickImage: (_) async => fileOf('fabric.gif'),
      compressor: _ShrinkCompressor(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Unsupported format. Use JPG, PNG, or WebP.'),
        findsOneWidget);
    expect(repo.lastSavedImages, isNull);
  });

  testWidgets('an oversize post-compression payload is rejected',
      (tester) async {
    await tester.pumpWidget(harness(
      pickImage: (_) async => fileOf('fabric.jpg'),
      compressor: _OversizeCompressor(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Image is too large after compression.'), findsOneWidget);
    expect(repo.lastSavedImages, isNull);
  });

  testWidgets('a throwing save is reported without leaving the mutation stuck',
      (tester) async {
    repo.imagePathsResult = const Success(<String>['product-images/pid/a.jpg']);
    repo.setImagesError = StateError('boom');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Upload failed. Please try again.'), findsOneWidget);
    expect(find.byType(AppImage), findsOneWidget);
  });

  testWidgets('queued mutations stop when the page is unmounted first',
      (tester) async {
    repo.imagePathsResult = const Success(<String>[
      'product-images/pid/a.jpg',
      'product-images/pid/b.jpg',
      'product-images/pid/c.jpg',
    ]);
    final first = Completer<Result<void>>();
    repo.setImagesHandler = (productId, paths) => first.future;

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final downButtons = find.byIcon(Icons.arrow_downward);
    await tester.tap(downButtons.at(0));
    await tester.pump();
    expect(repo.lastSavedImages, isNotNull,
        reason: 'the first mutation must be in flight before the second');
    await tester.tap(downButtons.at(1));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    first.complete(const Success(null));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repo.lastSavedImages, hasLength(3));
  });

  testWidgets('a save failing after unmount completes without touching UI',
      (tester) async {
    repo.imagePathsResult = const Success(<String>['product-images/pid/a.jpg']);
    final pending = Completer<Result<void>>();
    repo.setImagesHandler = (productId, paths) => pending.future;

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(repo.lastSavedImages, isNotNull,
        reason: 'the mutation must have started before the page is unmounted');

    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('late failure'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
