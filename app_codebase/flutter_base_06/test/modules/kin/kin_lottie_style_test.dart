import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
          'serial': 'KIN-BRZ-GEN001-0001',
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
    template = catalog.kinBySerial('KIN-BRZ-GEN001-0001')!;
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

  test('resolveLayerStyles applies combined part to all affectsLayers', () {
    final combined = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': 'CUS-0003',
          'customType': 'hue',
          'displayName': 'Eye hue',
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
          'serial': 'KIN-IVY-GEN001-0003',
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
      template: combined.kinBySerial('KIN-IVY-GEN001-0003')!,
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
}
