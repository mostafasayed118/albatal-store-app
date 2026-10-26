import 'package:al_batal_elite/shared/components/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class _StubAssetBundle extends CachingAssetBundle {
  static const List<String> _assets = <String>[
    'assets/brand/logo_lockup_on_dark.png',
    'assets/brand/logo_lockup_on_light.png',
    'assets/brand/logo_mark_on_dark.png',
    'assets/brand/logo_mark_on_light.png',
  ];

  static final ByteData _pixel = ByteData.sublistView(Uint8List.fromList(
    const <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ],
  ));

  static final ByteData _manifest = const StandardMessageCodec().encodeMessage(
    <String, Object?>{
      for (final asset in _assets)
        asset: <Object?>[
          <String, Object?>{'asset': asset, 'dpr': 1.0},
        ],
    },
  )!;

  @override
  Future<ByteData> load(String key) async =>
      key == 'AssetManifest.bin' ? _manifest : _pixel;
}

Widget _host(
  Widget logo, {
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: DefaultAssetBundle(
      bundle: _StubAssetBundle(),
      child: Scaffold(body: Center(child: logo)),
    ),
  );
}

String _resolvedAsset(WidgetTester tester) {
  final provider = tester.widget<Image>(find.byType(Image)).image;
  final resolved = provider is ResizeImage ? provider.imageProvider : provider;
  return (resolved as AssetImage).assetName;
}

void main() {
  testWidgets('lockup resolves the on-dark asset in a dark theme',
      (tester) async {
    await tester.pumpWidget(
      _host(const BrandLogo.lockup(), brightness: Brightness.dark),
    );

    expect(_resolvedAsset(tester), 'assets/brand/logo_lockup_on_dark.png');
  });

  testWidgets('lockup resolves the on-light asset in a light theme',
      (tester) async {
    await tester.pumpWidget(_host(const BrandLogo.lockup()));

    expect(_resolvedAsset(tester), 'assets/brand/logo_lockup_on_light.png');
  });

  testWidgets('explicit onDark tone overrides a light theme; mark height wins',
      (tester) async {
    await tester.pumpWidget(_host(
      const BrandLogo.mark(height: 34, tone: BrandLogoTone.onDark),
    ));

    final image = tester.widget<Image>(find.byType(Image));
    expect(_resolvedAsset(tester), 'assets/brand/logo_mark_on_dark.png');
    expect(image.height, 34);
  });
}
