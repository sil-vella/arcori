import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/kin/kin_lottie_embed.dart';
import 'package:arcori/modules/kin/kin_models.dart';
import 'package:image/image.dart' as img;

/// 1×1 opaque PNG.
final Uint8List _tinyPng = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
));

Map<String, dynamic> _layer(String nm, int ind) => {
      'ddd': 0,
      'ind': ind,
      'ty': 2,
      'nm': nm,
      'refId': 'a$ind',
      'sr': 1,
      'ks': {
        'o': {'a': 0, 'k': 100},
        'r': {'a': 0, 'k': 0},
        'p': {
          'a': 0,
          'k': [50, 50, 0]
        },
        'a': {
          'a': 0,
          'k': [0, 0, 0]
        },
        's': {
          'a': 0,
          'k': [100, 100, 100]
        },
      },
      'ip': 0,
      'op': 30,
      'st': 0,
      'bm': 0,
    };

void main() {
  late KinCreationCatalog catalog;
  late KinTemplate template;

  setUp(() {
    catalog = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': 'CUS-0006',
          'customType': 'embedImage',
          'displayName': 'Embed',
          'params': {},
        }),
      ],
      embeds: [
        KinEmbed.fromJson({
          'serial': 'KEMB-0001',
          'displayName': 'Spark',
          'assetPath': 'assets/images/branding/icon.png',
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
              'serial': 'KPART-T',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': ['CUS-0006'],
              'embedPoolSerials': ['KEMB-0001'],
              'embedPlacements': {
                'KEMB-0001': {
                  'inFrontOf': 'metallic_plate',
                  'p': [10, 20, 0],
                  's': [30, 30, 100],
                },
              },
            },
          ],
        }),
      ],
    );
    template = catalog.kins.first;
  });

  test('KinEmbedPlacement.fromJson parses inFrontOf p s', () {
    final p = KinEmbedPlacement.fromJson({
      'inFrontOf': 'metallic_plate',
      'p': [1, 2],
      's': [40, 50],
    });
    expect(p.targetLayer, 'metallic_plate');
    expect(p.side, KinEmbedSide.inFront);
    expect(p.p, [1.0, 2.0, 0.0]);
    expect(p.s, [40.0, 50.0, 100.0]);
    expect(p.isValid, isTrue);
    expect(KinEmbedPlacement.fromJson({'inFrontOf': ''}).isValid, isFalse);
  });

  test('KinEmbedPlacement.fromJson parses behindLayer', () {
    final p = KinEmbedPlacement.fromJson({'behindLayer': 'body'});
    expect(p.targetLayer, 'body');
    expect(p.side, KinEmbedSide.behind);
    expect(p.isValid, isTrue);
  });

  test('KinEmbedPlacement rejects both or neither keys', () {
    expect(
      KinEmbedPlacement.fromJson({
        'inFrontOf': 'a',
        'behindLayer': 'b',
      }).isValid,
      isFalse,
    );
    expect(KinEmbedPlacement.fromJson({}).isValid, isFalse);
  });

  test('resolveEmbedJobs skips missing placement', () {
    final noPlace = KinTemplate.fromJson({
      'serial': 'KIN-N',
      'typeSerial': 'KTYPE-0001',
      'displayName': 'N',
      'parts': [
        {
          'serial': 'KPART-N',
          'layerName': 'head',
          'displayName': 'Head',
          'allowedCustomSerials': ['CUS-0006'],
          'embedPoolSerials': ['KEMB-0001'],
        },
      ],
    });
    final jobs = resolveEmbedJobs(
      template: noPlace,
      catalog: catalog,
      applied: const [
        KinAppliedCustom(
          partSerial: 'KPART-N',
          customSerial: 'CUS-0006',
          value: 'KEMB-0001',
        ),
      ],
    );
    expect(jobs, isEmpty);
  });

  test('resolveEmbedJobs returns placement for allowed embed', () {
    final jobs = resolveEmbedJobs(
      template: template,
      catalog: catalog,
      applied: const [
        KinAppliedCustom(
          partSerial: 'KPART-T',
          customSerial: 'CUS-0006',
          value: 'KEMB-0001',
        ),
      ],
    );
    expect(jobs, hasLength(1));
    expect(jobs.first.targetLayer, 'metallic_plate');
    expect(jobs.first.side, KinEmbedSide.inFront);
    expect(jobs.first.p, [10.0, 20.0, 0.0]);
  });

  test('resolveEmbedJobs supports multi-select map', () {
    final multi = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': 'CUS-0006',
          'customType': 'embedImage',
          'displayName': 'Embed',
          'params': {},
        }),
      ],
      embeds: [
        KinEmbed.fromJson({
          'serial': 'KEMB-0001',
          'displayName': 'A',
          'assetPath': 'assets/a.png',
        }),
        KinEmbed.fromJson({
          'serial': 'KEMB-0002',
          'displayName': 'B',
          'assetPath': 'assets/b.png',
        }),
      ],
      types: const [],
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-M',
          'typeSerial': 'KTYPE-0001',
          'displayName': 'M',
          'parts': [
            {
              'serial': 'KPART-M',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': ['CUS-0006'],
              'embedPoolSerials': ['KEMB-0001', 'KEMB-0002'],
              'embedPlacements': {
                'KEMB-0001': {'inFrontOf': 'head'},
                'KEMB-0002': {'behindLayer': 'body'},
              },
            },
          ],
        }),
      ],
    );
    final jobs = resolveEmbedJobs(
      template: multi.kins.first,
      catalog: multi,
      applied: [
        KinAppliedCustom(
          partSerial: 'KPART-M',
          customSerial: 'CUS-0006',
          value: {
            'KEMB-0002': {'hue': 0.0, 'lightDark': 0.0},
            'KEMB-0001': {'hue': 0.0, 'lightDark': 0.0},
          },
        ),
      ],
    );
    expect(jobs.map((j) => j.embedSerial).toList(), ['KEMB-0002', 'KEMB-0001']);
  });

  test('same inFrontOf target stacks higher serial in front (HMG/HGD)', () {
    // Tiny 1x1 PNG
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    const raw = '''
{"w":8,"h":8,"ip":0,"op":30,"assets":[],"layers":[
  {"nm":"eyes","ty":2,"refId":"a","ind":1},
  {"nm":"body","ty":2,"refId":"b","ind":2},
  {"nm":"metallic_plate","ty":2,"refId":"c","ind":3}
]}''';
    final baked = bakeKinEmbedsIntoLottieSync(raw, [
      KinEmbedBakeJob(
        embedSerial: 'KEMB-0025',
        targetLayer: 'eyes',
        side: KinEmbedSide.inFront,
        assetPath: 'x',
        pngBytes: png,
      ),
      KinEmbedBakeJob(
        embedSerial: 'KEMB-0026',
        targetLayer: 'eyes',
        side: KinEmbedSide.inFront,
        assetPath: 'x',
        pngBytes: png,
      ),
    ]);
    // Jobs passed unsorted; bake uses list order as given — callers must sort
    // via resolveEmbedJobs. Simulate that order (desc serial):
    final ordered = bakeKinEmbedsIntoLottieSync(raw, [
      KinEmbedBakeJob(
        embedSerial: 'KEMB-0026',
        targetLayer: 'eyes',
        side: KinEmbedSide.inFront,
        assetPath: 'x',
        pngBytes: png,
      ),
      KinEmbedBakeJob(
        embedSerial: 'KEMB-0025',
        targetLayer: 'eyes',
        side: KinEmbedSide.inFront,
        assetPath: 'x',
        pngBytes: png,
      ),
    ]);
    final names = ((jsonDecode(ordered) as Map)['layers'] as List)
        .map((e) => (e as Map)['nm'])
        .toList();
    expect(names.take(3).toList(), [
      'embed_KEMB-0026',
      'embed_KEMB-0025',
      'eyes',
    ]);
    // Silence unused
    expect(baked, isNotEmpty);
  });

  test('bakeKinEmbedsIntoLottieSync inserts in front of target and is idempotent',
      () {
    final raw = jsonEncode({
      'v': '5.7.4',
      'fr': 30,
      'ip': 0,
      'op': 30,
      'w': 100,
      'h': 100,
      'nm': 't',
      'ddd': 0,
      'assets': <dynamic>[],
      'layers': [
        _layer('head', 1),
        _layer('body', 2),
        _layer('metallic_plate', 3),
      ],
    });

    final job = KinEmbedBakeJob(
      embedSerial: 'KEMB-0001',
      targetLayer: 'metallic_plate',
      side: KinEmbedSide.inFront,
      assetPath: 'x',
      p: [10, 20, 0],
      s: [30, 30, 100],
      pngBytes: _tinyPng,
    );

    final once = bakeKinEmbedsIntoLottieSync(raw, [job]);
    final layers1 = (jsonDecode(once) as Map)['layers'] as List;
    final names1 = layers1.map((e) => (e as Map)['nm']).toList();
    expect(names1, ['head', 'body', 'embed_KEMB-0001', 'metallic_plate']);
    final metalIdx = names1.indexOf('metallic_plate');
    final embIdx = names1.indexOf('embed_KEMB-0001');
    expect(embIdx, metalIdx - 1);

    final twice = bakeKinEmbedsIntoLottieSync(once, [job]);
    final layers2 = (jsonDecode(twice) as Map)['layers'] as List;
    final embeds =
        layers2.where((e) => (e as Map)['nm'] == 'embed_KEMB-0001').length;
    expect(embeds, 1);
    expect(
      layers2.map((e) => (e as Map)['nm']).toList(),
      ['head', 'body', 'embed_KEMB-0001', 'metallic_plate'],
    );
  });

  test('bake keeps full addition canvas (no independent 512 shrink)', () async {
    // Transparent padding holds position — must match composition space.
    final big = img.Image(width: 800, height: 800);
    img.fill(big, color: img.ColorRgba8(0, 0, 0, 0));
    img.fillRect(
      big,
      x1: 350,
      y1: 350,
      x2: 450,
      y2: 450,
      color: img.ColorRgba8(255, 0, 0, 255),
    );
    final pngBytes = Uint8List.fromList(img.encodePng(big));

    final raw = jsonEncode({
      'v': '5.7.4',
      'w': 800,
      'h': 800,
      'assets': <dynamic>[],
      'layers': [_layer('left_eye', 1)],
    });
    final out = await bakeKinEmbedsIntoLottie(raw, [
      KinEmbedBakeJob(
        embedSerial: 'KEMB-BIG',
        targetLayer: 'left_eye',
        side: KinEmbedSide.inFront,
        assetPath: 'x',
        pngBytes: pngBytes,
      ),
    ]);
    final decoded = jsonDecode(out) as Map<String, dynamic>;
    final assets = decoded['assets'] as List;
    expect(assets, hasLength(1));
    expect(assets.first['w'], 800);
    expect(assets.first['h'], 800);
    final layer = (decoded['layers'] as List).firstWhere(
      (e) => (e as Map)['nm'] == 'embed_KEMB-BIG',
    ) as Map;
    expect((layer['ks'] as Map)['p']['k'], [0.0, 0.0, 0.0]);
    expect((layer['ks'] as Map)['a']['k'], [0.0, 0.0, 0.0]);
    expect((layer['ks'] as Map)['s']['k'], [100.0, 100.0, 100.0]);
  });

  test('bake inserts behind target after body', () {
    final raw = jsonEncode({
      'v': '5.7.4',
      'fr': 30,
      'ip': 0,
      'op': 30,
      'w': 100,
      'h': 100,
      'nm': 't',
      'assets': <dynamic>[],
      'layers': [
        _layer('left_eye', 1),
        _layer('head', 2),
        _layer('body', 3),
      ],
    });
    final out = bakeKinEmbedsIntoLottieSync(raw, [
      KinEmbedBakeJob(
        embedSerial: 'KEMB-SPEAR',
        targetLayer: 'body',
        side: KinEmbedSide.behind,
        assetPath: 'x',
        pngBytes: _tinyPng,
      ),
    ]);
    final names =
        ((jsonDecode(out) as Map)['layers'] as List).map((e) => (e as Map)['nm']);
    expect(names.toList(), ['left_eye', 'head', 'body', 'embed_KEMB-SPEAR']);
  });

  test('bake inserts in front of topmost layer', () {
    final raw = jsonEncode({
      'v': '5.7.4',
      'fr': 30,
      'ip': 0,
      'op': 30,
      'w': 50,
      'h': 50,
      'nm': 't',
      'assets': <dynamic>[],
      'layers': [
        _layer('head', 1),
        _layer('body', 2),
      ],
    });
    final out = bakeKinEmbedsIntoLottieSync(raw, [
      KinEmbedBakeJob(
        embedSerial: 'KEMB-0001',
        targetLayer: 'head',
        side: KinEmbedSide.inFront,
        assetPath: 'x',
        pngBytes: _tinyPng,
      ),
    ]);
    final names =
        ((jsonDecode(out) as Map)['layers'] as List).map((e) => (e as Map)['nm']);
    expect(names.toList(), ['embed_KEMB-0001', 'head', 'body']);
  });

  test('bake no-ops when target layer missing', () {
    final raw = jsonEncode({
      'v': '5.7.4',
      'fr': 30,
      'ip': 0,
      'op': 30,
      'w': 50,
      'h': 50,
      'nm': 't',
      'assets': <dynamic>[],
      'layers': [
        _layer('only', 1),
      ],
    });
    final out = bakeKinEmbedsIntoLottieSync(raw, [
      KinEmbedBakeJob(
        embedSerial: 'KEMB-0001',
        targetLayer: 'missing',
        side: KinEmbedSide.inFront,
        assetPath: 'x',
        pngBytes: _tinyPng,
      ),
    ]);
    final layers = (jsonDecode(out) as Map)['layers'] as List;
    expect(layers, hasLength(1));
    expect((layers.first as Map)['nm'], 'only');
  });

  test('kinPreviewEmbedSignature ignores tint, includes placement', () {
    final appliedA = [
      KinAppliedCustom(
        partSerial: 'KPART-T',
        customSerial: 'CUS-0006',
        value: {
          'KEMB-0001': {'hue': 10.0, 'lightDark': 0.2},
        },
      ),
    ];
    final appliedB = [
      KinAppliedCustom(
        partSerial: 'KPART-T',
        customSerial: 'CUS-0006',
        value: {
          'KEMB-0001': {'hue': 90.0, 'lightDark': -0.5},
        },
      ),
    ];
    final sigA = kinPreviewEmbedSignature(
      template: template,
      catalog: catalog,
      applied: appliedA,
    );
    expect(sigA, contains('KEMB-0001:'));
    expect(sigA, contains('metallic_plate'));
    expect(
      kinPreviewEmbedSignature(
        template: template,
        catalog: catalog,
        applied: appliedA,
      ),
      kinPreviewEmbedSignature(
        template: template,
        catalog: catalog,
        applied: appliedB,
      ),
    );
    expect(
      kinPreviewEmbedSignature(
        template: template,
        catalog: catalog,
        applied: const [],
      ),
      '',
    );

    final multi = KinCreationCatalog(
      customTypes: const [],
      customs: catalog.customs,
      embeds: [
        ...catalog.embeds,
        KinEmbed.fromJson({
          'serial': 'KEMB-0002',
          'displayName': 'B',
          'assetPath': 'assets/b.png',
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
              'serial': 'KPART-T',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': ['CUS-0006'],
              'embedPoolSerials': ['KEMB-0001', 'KEMB-0002'],
              'embedPlacements': {
                'KEMB-0001': {'inFrontOf': 'metallic_plate'},
                'KEMB-0002': {'behindLayer': 'body'},
              },
            },
          ],
        }),
      ],
    );
    final multiSig = kinPreviewEmbedSignature(
      template: multi.kins.first,
      catalog: multi,
      applied: [
        KinAppliedCustom(
          partSerial: 'KPART-T',
          customSerial: 'CUS-0006',
          value: {
            'KEMB-0002': {'hue': 0.0, 'lightDark': 0.0},
            'KEMB-0001': {'hue': 0.0, 'lightDark': 0.0},
          },
        ),
      ],
    );
    expect(multiSig, contains('KEMB-0001:'));
    expect(multiSig, contains('KEMB-0002:'));

    // Placement p change must change signature.
    final nudged = KinCreationCatalog(
      customTypes: catalog.customTypes,
      customs: catalog.customs,
      embeds: catalog.embeds,
      types: catalog.types,
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-T',
          'typeSerial': 'KTYPE-0001',
          'displayName': 'T',
          'parts': [
            {
              'serial': 'KPART-T',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': ['CUS-0006'],
              'embedPoolSerials': ['KEMB-0001'],
              'embedPlacements': {
                'KEMB-0001': {
                  'inFrontOf': 'metallic_plate',
                  'p': [100.0, 200.0, 0],
                },
              },
            },
          ],
        }),
      ],
    );
    expect(
      kinPreviewEmbedSignature(
        template: nudged.kins.first,
        catalog: nudged,
        applied: appliedA,
      ),
      isNot(sigA),
    );
  });

  test('bakeKinEmbedsIntoLottieSync defaults to compact JSON', () {
    final raw = jsonEncode({
      'v': '5.7.4',
      'fr': 30,
      'ip': 0,
      'op': 30,
      'w': 50,
      'h': 50,
      'nm': 't',
      'assets': <dynamic>[],
      'layers': [
        _layer('head', 1),
      ],
    });
    final compact = bakeKinEmbedsIntoLottieSync(raw, [
      KinEmbedBakeJob(
        embedSerial: 'KEMB-0001',
        targetLayer: 'head',
        side: KinEmbedSide.inFront,
        assetPath: 'x',
        pngBytes: _tinyPng,
      ),
    ]);
    expect(compact.contains('\n'), isFalse);
    final pretty = bakeKinEmbedsIntoLottieSync(
      raw,
      [
        KinEmbedBakeJob(
          embedSerial: 'KEMB-0001',
          targetLayer: 'head',
          side: KinEmbedSide.inFront,
          assetPath: 'x',
          pngBytes: _tinyPng,
        ),
      ],
      pretty: true,
    );
    expect(pretty.contains('\n'), isTrue);
  });
}
