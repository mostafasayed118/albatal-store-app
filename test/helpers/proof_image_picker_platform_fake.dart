// ignore_for_file: depend_on_referenced_packages
// `image_picker_platform_interface` is transitive via the `image_picker`
// dependency; tests need it to install a platform fake.
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Test double for the image-picker platform channel.
///
/// Installed via `ImagePickerPlatform.instance = ...` so both the pure
/// picker function and widgets that construct `ImagePicker()` internally
/// (InstapayInstructionsPage) can be driven without a real gallery.
class ProofImagePickerPlatformFake extends ImagePickerPlatform {
  ProofImagePickerPlatformFake({this.file, this.error});

  /// File returned by [getImageFromSource] (null = user cancelled).
  XFile? file;

  /// When set, thrown instead of returning [file].
  Object? error;

  int calls = 0;
  ImageSource? lastSource;
  ImagePickerOptions? lastOptions;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls++;
    lastSource = source;
    lastOptions = options;
    final failure = error;
    if (failure != null) throw failure;
    return file;
  }
}
