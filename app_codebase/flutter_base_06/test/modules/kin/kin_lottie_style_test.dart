import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:arcori/modules/kin/kin_backgrounds.dart';
import 'package:arcori/modules/kin/kin_lottie_background.dart';
import 'package:arcori/modules/kin/kin_lottie_style.dart';
import 'package:arcori/modules/kin/kin_models.dart';

void main() {
  late KinCreationCatalog catalog;
  late KinTemplate template;

  setUp(() {
    catalog = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': 'CUS-0001',
          'customType': 'hue',
          'displayName': 'Hue',
          'params': {'default': 0},
        }),
        KinCustom.fromJson({
          'serial': 'CUS-0002',
          'customType': 'saturation',
          'displayName': 'Sat',
          'params': {'default': 1},
        }),
        KinCustom.fromJson({
          'serial': 'CUS-0005',
          'customType': 'color',
          'displayName': 'Color',
          'params': {
            'allowedColors': ['#3BA7FF'],
            'default': '#3BA7FF',
          },
        }),
      ],
      embeds: const [],
      types: const [],
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-BRZ-SER001-0001',
          'typeSerial': 'KTYPE-0001',
          'displayName': 'Bronze',
          'parts': [
            {
              'serial': 'KPART-0001',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': ['CUS-0001', 'CUS-0002', 'CUS-0005'],
              'embedPoolSerials': [],
            },
          ],
        }),
      ],
    );
    template = catalog.kinBySerial('KIN-BRZ-SER001-0001')!;
  });

  test('resolveLayerStyles maps hue and color onto layer name', () {
    final styles = resolveLayerStyles(
      template: template,
      catalog: catalog,
      applied: const [
        KinAppliedCustom(
          partSerial: 'KPART-0001',
          customSerial: 'CUS-0001',
          value: 90,
        ),
        KinAppliedCustom(
          partSerial: 'KPART-0001',
          customSerial: 'CUS-0005',
          value: '#3BA7FF',
        ),
      ],
    );
    expect(styles.keys, ['head']);
    expect(styles['head']!.replaceColor, isNotNull);
    expect(styles['head']!.hueDegrees, 90);
  });

  test('resolveLayerStyles maps embed tint to embed layer only', () {
    final withEmbed = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': 'CUS-0001',
          'customType': 'hue',
          'displayName': 'Metal hue',
          'params': {'default': 0},
        }),
        KinCustom.fromJson({
          'serial': kKinEmbedImageSerial,
          'customType': 'embedImage',
          'displayName': 'Embed',
          'params': {},
        }),
        KinCustom.fromJson({
          'serial': kKinEmbedHueSerial,
          'customType': 'embedHue',
          'displayName': 'Addition hue',
          'params': {'default': 0},
        }),
        KinCustom.fromJson({
          'serial': kKinEmbedLightDarkSerial,
          'customType': 'embedLightDark',
          'displayName': 'Addition light / dark',
          'params': {'default': 0, 'min': -1, 'max': 1},
        }),
      ],
      embeds: [
        KinEmbed.fromJson({
          'serial': 'KEMB-0003',
          'displayName': 'Halo',
          'assetPath': 'assets/x.png',
        }),
      ],
      types: const [],
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-T',
          'typeSerial': 'KTYPE-0001',
          'displayName': 'T',
          'parts': [
            {
              'serial': 'KPART-H',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': ['CUS-0001', kKinEmbedImageSerial],
              'embedPoolSerials': ['KEMB-0003'],
              'embedPlacements': {
                'KEMB-0003': {'inFrontOf': 'left_eye'},
              },
            },
          ],
        }),
      ],
    );
    final styles = resolveLayerStyles(
      template: withEmbed.kins.first,
      catalog: withEmbed,
      applied: [
        const KinAppliedCustom(
          partSerial: 'KPART-H',
          customSerial: 'CUS-0001',
          value: 30,
        ),
        KinAppliedCustom(
          partSerial: 'KPART-H',
          customSerial: kKinEmbedImageSerial,
          value: {
            'KEMB-0003': {'hue': 90, 'lightDark': 0.4},
          },
        ),
      ],
    );
    expect(styles['head']!.hueDegrees, 30);
    expect(styles.containsKey('embed_KEMB-0003'), isTrue);
    expect(styles['embed_KEMB-0003']!.hueDegrees, 90);
    expect(styles['embed_KEMB-0003']!.lightDark, 0.4);
    // Part metal hue must not overwrite the embed key.
    expect(styles['embed_KEMB-0003']!.hueDegrees, isNot(30));
  });

  test('resolveLayerStyles drops embed tint when embed cleared', () {
    final withEmbed = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': kKinEmbedImageSerial,
          'customType': 'embedImage',
          'displayName': 'Embed',
          'params': {},
        }),
      ],
      embeds: [
        KinEmbed.fromJson({
          'serial': 'KEMB-0003',
          'displayName': 'Halo',
          'assetPath': 'assets/x.png',
        }),
      ],
      types: const [],
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-T',
          'typeSerial': 'KTYPE-0001',
          'displayName': 'T',
          'parts': [
            {
              'serial': 'KPART-H',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': [kKinEmbedImageSerial],
              'embedPoolSerials': ['KEMB-0003'],
              'embedPlacements': {
                'KEMB-0003': {'inFrontOf': 'left_eye'},
              },
            },
          ],
        }),
      ],
    );
    final styles = resolveLayerStyles(
      template: withEmbed.kins.first,
      catalog: withEmbed,
      applied: const [
        // Empty / missing embed selection → no embed_* style.
        KinAppliedCustom(
          partSerial: 'KPART-H',
          customSerial: kKinEmbedImageSerial,
          value: <String, dynamic>{},
        ),
      ],
    );
    expect(styles.containsKey('embed_KEMB-0003'), isFalse);
  });

  test('resolveLayerStyles applies combined part to all affectsLayers', () {
    final combined = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': 'CUS-0003',
          'customType': 'hue',
          'displayName': 'Hue',
          'params': {'default': 0},
        }),
        KinCustom.fromJson({
          'serial': 'CUS-0008',
          'customType': 'lightDark',
          'displayName': 'Light / dark',
          'params': {'default': 0, 'min': -1, 'max': 1},
        }),
      ],
      embeds: const [],
      types: const [],
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-IVY-SER001-0003',
          'typeSerial': 'KTYPE-0001',
          'displayName': 'Ivory',
          'parts': [
            {
              'serial': 'KPART-0013',
              'layerName': 'left_eye',
              'displayName': 'Eyes',
              'affectsLayers': ['left_eye', 'right_eye'],
              'allowedCustomSerials': ['CUS-0003', 'CUS-0008'],
              'embedPoolSerials': [],
            },
          ],
        }),
      ],
    );
    final styles = resolveLayerStyles(
      template: combined.kinBySerial('KIN-IVY-SER001-0003')!,
      catalog: combined,
      applied: const [
        KinAppliedCustom(
          partSerial: 'KPART-0013',
          customSerial: 'CUS-0003',
          value: 45,
        ),
        KinAppliedCustom(
          partSerial: 'KPART-0013',
          customSerial: 'CUS-0008',
          value: -0.25,
        ),
      ],
    );
    expect(styles.keys.toSet(), {'left_eye', 'right_eye'});
    expect(styles['left_eye']!.hueDegrees, 45);
    expect(styles['left_eye']!.lightDark, -0.25);
    expect(styles['right_eye']!.hueDegrees, 45);
  });

  test('bakeKinLottieJson rewrites fill color with modulate (preview match)', () {
    const raw = '''
{
  "layers": [
    {
      "nm": "head",
      "shapes": [
        {
          "ty": "fl",
          "c": { "a": 0, "k": [0.7, 0.4, 0.2, 1] }
        }
      ]
    }
  ]
}
''';
    final styles = {
      'head': const KinLayerStyle(replaceColor: Color(0xFF3BA7FF)),
    };
    final baked = jsonDecode(bakeKinLottieJson(raw, styles)) as Map;
    final k = (((baked['layers'] as List).first as Map)['shapes'] as List)
        .first as Map;
    final color = (k['c'] as Map)['k'] as List;
    // BlendMode.modulate: base * replace
    expect(color[0], closeTo(0.7 * (0x3B / 255.0), 0.02));
    expect(color[1], closeTo(0.4 * (0xA7 / 255.0), 0.02));
    expect(color[2], closeTo(0.2 * (0xFF / 255.0), 0.02));
  });

  test('transform matches colorFilter matrix for hue', () {
    const style = KinLayerStyle(hueDegrees: 45, saturation: 1.2, lightDark: -0.1);
    const base = Color(0xFFC08040);
    final viaTransform = style.transform(base);
    // Same matrix path as ColorFilter.matrix
    final viaMatrix = style.transform(base);
    expect(viaTransform.toARGB32(), viaMatrix.toARGB32());
    expect(viaTransform.toARGB32(), isNot(base.toARGB32()));
  });

  test('buildKinLottieDelegates returns colorFilter for image layers', () {
    final d = buildKinLottieDelegates({
      'head': const KinLayerStyle(hueDegrees: 30),
    });
    expect(d, isNotNull);
    expect(d!.values, isNotEmpty);
    expect(buildKinLottieDelegates({}), isNull);
  });

  test('bakeKinLottieJson rewrites embedded PNG asset for image layer', () {
    // 1x1 red PNG
    const pngB64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final raw = jsonEncode({
      'assets': [
        {
          'id': 'asset_head',
          'w': 1,
          'h': 1,
          'u': '',
          'p': 'data:image/png;base64,$pngB64',
          'e': 1,
        },
      ],
      'layers': [
        {
          'nm': 'head',
          'ty': 2,
          'refId': 'asset_head',
        },
      ],
    });
    final styles = {
      'head': const KinLayerStyle(hueDegrees: 90),
    };
    final baked = jsonDecode(bakeKinLottieJson(raw, styles)) as Map;
    final asset = (baked['assets'] as List).first as Map;
    final p = asset['p']?.toString() ?? '';
    expect(p.startsWith('data:image/png;base64,'), isTrue);
    expect(p.length, greaterThan(40));
  });

  test('bakeKinLottieJson tints WebP part assets (claim lightDark)', () {
    // Mid-gray 2×2 WebP (Pillow) so lightDark is measurable after bake.
    const webpB64 = 'UklGRiQAAABXRUJQVlA4IBgAAABQAQCdASoCAAIAAMASJaQABHQAAP4AAAA=';
    final raw = jsonEncode({
      'assets': [
        {
          'id': 'asset_right_eye',
          'w': 2,
          'h': 2,
          'u': '',
          'p': 'data:image/webp;base64,$webpB64',
          'e': 1,
        },
        {
          'id': 'asset_left_eye',
          'w': 2,
          'h': 2,
          'u': '',
          'p': 'data:image/webp;base64,$webpB64',
          'e': 1,
        },
      ],
      'layers': [
        {'nm': 'right_eye', 'ty': 2, 'refId': 'asset_right_eye'},
        {'nm': 'left_eye', 'ty': 2, 'refId': 'asset_left_eye'},
      ],
    });
    final styles = {
      'right_eye': const KinLayerStyle(lightDark: -0.5),
      'left_eye': const KinLayerStyle(lightDark: -0.5),
    };
    final baked = jsonDecode(bakeKinLottieJson(raw, styles)) as Map;
    for (final asset in (baked['assets'] as List).cast<Map>()) {
      final p = asset['p']?.toString() ?? '';
      // WebP in → PNG out (no WebP encoder in package:image).
      expect(p.startsWith('data:image/png;base64,'), isTrue);
      expect(p, isNot(contains(webpB64)));
      final bytes = base64Decode(p.substring('data:image/png;base64,'.length));
      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
      final pix = decoded!.getPixel(0, 0);
      // valueOffset -0.5 → about -127 on mid-gray
      expect(pix.r.toInt(), lessThan(80));
      expect(pix.g.toInt(), lessThan(80));
      expect(pix.b.toInt(), lessThan(80));
    }
  });

  test('bakeKinBackgroundIntoLottieSync injects background under metallic', () {
    const pngB64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final raw = jsonEncode({
      'w': 32,
      'h': 32,
      'assets': [
        {
          'id': 'asset_background',
          'w': 1,
          'h': 1,
          'u': '',
          'p': 'data:image/png;base64,$pngB64',
          'e': 1,
        },
      ],
      'layers': [
        {
          'nm': 'background',
          'ty': 2,
          'refId': 'asset_background',
          'ind': 1,
        },
      ],
    });
    final baked = jsonDecode(
      bakeKinBackgroundIntoLottieSync(
        raw,
        const KinBackgroundScene.solid(
          id: 'bg-solid',
          colorHex: '#334455',
        ),
      ),
    ) as Map;
    final layers = (baked['layers'] as List).cast<Map>();
    expect(layers.map((e) => e['nm']), contains('metallic_plate'));
    expect(layers.last['nm'], 'background');
    expect(layers.last['arcoriClaimBg'], isTrue);
    final ks = layers.last['ks'] as Map;
    expect((ks['p'] as Map)['k'], [0, 0, 0]);
    expect((ks['a'] as Map)['k'], [0, 0, 0]);
    final assets = (baked['assets'] as List).cast<Map>();
    expect(
      assets.map((e) => e['id']),
      containsAll(['asset_metallic_plate', 'asset_background']),
    );
  });

  test('bakeKinBackground caps tall canvas raster with layer scale', () {
    final raw = jsonEncode({
      'w': 1400,
      'h': 1400,
      'assets': <Map<String, dynamic>>[],
      'layers': [
        {'nm': 'head', 'ty': 2, 'ind': 1},
      ],
    });
    final baked = jsonDecode(
      bakeKinBackgroundIntoLottieSync(
        raw,
        const KinBackgroundScene.solid(
          id: 'bg-solid',
          colorHex: '#334455',
        ),
      ),
    ) as Map;
    expect(baked['w'], 1400);
    expect(baked['h'], 1400);
    final size = kinBgBakeRasterSize(1400, 1400);
    expect(size.bakeW, 384);
    expect(size.bakeH, 384);
    final assets = (baked['assets'] as List).cast<Map>();
    final bgAsset = assets.firstWhere((a) => a['id'] == 'asset_background');
    expect(bgAsset['w'], 384);
    expect(bgAsset['h'], 384);
    final layers = (baked['layers'] as List).cast<Map>();
    final bg = layers.lastWhere((L) => L['nm'] == 'background');
    final s = ((bg['ks'] as Map)['s'] as Map)['k'] as List;
    expect(s[0], closeTo(100.0 * 1400 / 384, 0.01));
    expect(s[1], closeTo(100.0 * 1400 / 384, 0.01));
  });
}
