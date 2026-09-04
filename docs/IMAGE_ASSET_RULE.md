# Image Asset Rule

Al Batal Elite uses SVG for every app-owned runtime image asset.

## Required

- Store local runtime images under `assets/images/` as `.svg` files.
- Render local runtime images through `AppImage` and `flutter_svg`.
- Keep product fixtures and serialized product image paths on `.svg`.
- Use remote image widgets only for remote URLs; their failure state must use
  the app's SVG/local fallback or a Material texture icon.
- Do not add PNG, JPEG, GIF, WebP, BMP, or AVIF files under `assets/images/`.

## Exceptions

- Android, iOS, macOS, and web launcher assets retain platform-required raster
  formats. They are packaging metadata, not Flutter runtime content.
- `docs/evidence/` screenshots and Stitch export screenshots retain raster
  formats because they are historical verification evidence.
- User-supplied remote catalog images are not controlled local assets; they are
  rendered through the remote-image path and degrade to the local fallback.

## Validation

The asset test in `test/image_asset_rule_test.dart` fails when a raster file is
added under `assets/images/`. The `AppImage` assertion also rejects local
runtime paths that do not end in `.svg` during debug/test execution.
