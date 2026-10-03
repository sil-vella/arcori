import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/kin/kin_embed_catalog.dart';
import 'package:arcori/modules/kin/kin_embed_selection.dart';
import 'package:arcori/modules/kin/kin_models.dart';

void main() {
  test('mergeKinRemoteEmbeds injects pool, placement, imageUrl', () {
    final base = KinCreationCatalog(
      customTypes: const [],
      customs: const [],
      embeds: [
        KinEmbed.fromJson({
          'serial': 'KEMB-OLD',
          'displayName': 'Old',
          'assetPath': 'assets/kin/embeds/old.png',
        }),
      ],
      types: const [],
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-T',
          'typeSerial': 'KTYPE-1',
          'displayName': 'T',
          'parts': [
            {
              'serial': 'KPART-H',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': ['CUS-0001'],
              'embedPoolSerials': <String>[],
            },
          ],
        }),
      ],
    );

    final merged = mergeKinRemoteEmbeds(base, [
      KinRemoteEmbed.fromJson({
        'serial': 'KEMB-NEW',
        'displayName': 'New halo',
        'imageUrl': '/catalog-media/kin/ser001/00embeds/halo.png',
        'attachments': [
          {
            'kinSerial': 'KIN-T',
            'partSerial': 'KPART-H',
            'placement': {'inFrontOf': 'left_eye'},
          },
        ],
      }),
    ]);

    final embed = merged.embedBySerial('KEMB-NEW');
    expect(embed, isNotNull);
    expect(embed!.imageUrl, '/catalog-media/kin/ser001/00embeds/halo.png');
    expect(embed.bakeSource, startsWith('/catalog-media/'));

    final part = merged.kinBySerial('KIN-T')!.partBySerial('KPART-H')!;
    expect(part.embedPoolSerials, contains('KEMB-NEW'));
    expect(part.allowsCustom(kKinEmbedImageSerial), isTrue);
    expect(part.placementFor('KEMB-NEW')!.targetLayer, 'left_eye');
    expect(part.placementFor('KEMB-NEW')!.side, KinEmbedSide.inFront);
  });

  test('merge prefers remote imageUrl over bundled assetPath', () {
    final base = KinCreationCatalog(
      customTypes: const [],
      customs: const [],
      embeds: [
        KinEmbed.fromJson({
          'serial': 'KEMB-0003',
          'displayName': 'Bronze halo',
          'assetPath': 'assets/kin/embeds/ser001/guardians/BRZ/halo.png',
        }),
      ],
      types: const [],
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-BRZ-SER001-0001',
          'typeSerial': 'KTYPE-0001',
          'displayName': 'Bronze',
          'parts': [
            {
              'serial': 'KPART-0003',
              'layerName': 'head',
              'displayName': 'Head',
              'allowedCustomSerials': ['CUS-0006'],
              'embedPoolSerials': ['KEMB-0003'],
              'embedPlacements': {
                'KEMB-0003': {'inFrontOf': 'old_layer'},
              },
            },
          ],
        }),
      ],
    );

    final merged = mergeKinRemoteEmbeds(base, [
      KinRemoteEmbed.fromJson({
        'serial': 'KEMB-0003',
        'displayName': 'Bronze halo',
        'imageUrl': '/catalog-media/kin/ser001/00embeds/guardians/BRZ/halo.png',
        'attachments': [
          {
            'kinSerial': 'KIN-BRZ-SER001-0001',
            'partSerial': 'KPART-0003',
            'placement': {'inFrontOf': 'left_eye'},
          },
        ],
      }),
    ]);

    final embed = merged.embedBySerial('KEMB-0003')!;
    expect(embed.assetPath, contains('assets/kin/embeds'));
    expect(embed.bakeSource, contains('/catalog-media/'));
    expect(
      merged
          .kinBySerial('KIN-BRZ-SER001-0001')!
          .partBySerial('KPART-0003')!
          .placementFor('KEMB-0003')!
          .targetLayer,
      'left_eye',
    );
  });

  test('bundled Entelair Head pools expose metallic_plate additions', () {
    final root = Directory.current.path.contains('flutter_base_06')
        ? Directory.current.path
        : '${Directory.current.path}/app_codebase/flutter_base_06';
    final embedsJson = jsonDecode(
      File('$root/assets/kin/embeds.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final kinsJson = jsonDecode(
      File('$root/assets/kin/kins.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final embeds = (embedsJson['embeds'] as List)
        .whereType<Map>()
        .map((e) => KinEmbed.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final kins = (kinsJson['kins'] as List)
        .whereType<Map>()
        .map((e) => KinTemplate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final catalog = KinCreationCatalog(
      customTypes: const [],
      customs: const [],
      embeds: embeds,
      types: const [],
      kins: kins,
    );

    final alc = catalog.kinBySerial('KIN-ALC-SER001-0005')!;
    final selectable = allSelectableEmbeds(template: alc, catalog: catalog);
    expect(selectable.map((e) => e.embed.serial).toList(), [
      'KEMB-0015',
      'KEMB-0016',
      'KEMB-0017',
      'KEMB-0018',
    ]);
    expect(
      selectable.every(
        (e) => e.part.placementFor(e.embed.serial)?.targetLayer == 'metallic_plate',
      ),
      isTrue,
    );
    expect(embeds.any((e) => e.serial == 'KEMB-0027'), isTrue);
  });
}
