import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/kin/kin_models.dart';
import 'package:arcori/modules/kin/kin_save_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KinCreationCatalog catalog;

  setUp(() {
    catalog = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': 'CUS-0001',
          'customType': 'hue',
          'displayName': 'Metal hue',
          'params': {'min': -180, 'max': 180, 'default': 0},
        }),
        KinCustom.fromJson({
          'serial': 'CUS-0006',
          'customType': 'embedImage',
          'displayName': 'Embed',
          'params': {},
        }),
        KinCustom.fromJson({
          'serial': 'CUS-0099',
          'customType': 'hue',
          'displayName': 'Orphan',
          'params': {},
        }),
      ],
      embeds: [
        KinEmbed.fromJson({
          'serial': 'KEMB-0001',
          'displayName': 'Spark',
          'assetPath': 'assets/images/branding/icon.png',
        }),
        KinEmbed.fromJson({
          'serial': 'KEMB-0099',
          'displayName': 'Forbidden',
          'assetPath': 'assets/images/branding/icon.png',
        }),
      ],
      types: [
        KinType.fromJson({
          'serial': 'KTYPE-0001',
          'code': 'guardians',
          'displayName': 'Guardians',
        }),
        KinType.fromJson({
          'serial': 'KTYPE-0002',
          'code': 'entelairs',
          'displayName': 'Entelairs',
        }),
      ],
      kins: [
        KinTemplate.fromJson({
          'serial': 'KIN-BRZ-GEN001-0001',
          'typeSerial': 'KTYPE-0001',
          'displayName': 'Bronze Genie',
          'lottieUrl': null,
          'parts': [
            {
              'serial': 'KPART-0001',
              'layerName': 'head',
              'displayName': 'Head',
              'anatomical': null,
              'allowedCustomSerials': ['CUS-0001', 'CUS-0006'],
              'embedPoolSerials': ['KEMB-0001'],
            },
            {
              'serial': 'KPART-0002',
              'layerName': 'left_arm',
              'displayName': 'Left arm',
              'anatomical': 'left',
              'allowedCustomSerials': ['CUS-0001'],
              'embedPoolSerials': [],
            },
          ],
        }),
        KinTemplate.fromJson({
          'serial': 'KIN-0099',
          'typeSerial': 'KTYPE-0002',
          'displayName': 'Other',
          'parts': [],
        }),
      ],
    );
  });

  group('KinCreationCatalog', () {
    test('filters kins by typeSerial', () {
      final guardians = catalog.kinsForType('KTYPE-0001');
      expect(guardians, hasLength(1));
      expect(guardians.first.serial, 'KIN-BRZ-GEN001-0001');
      expect(catalog.kinsForType('KTYPE-0002'), hasLength(1));
      expect(catalog.kinsForType('KTYPE-9999'), isEmpty);
    });

    test('allowedCustomsFor skips unknown serials', () {
      final part = catalog.kinBySerial('KIN-BRZ-GEN001-0001')!.parts.first;
      final allowed = catalog.allowedCustomsFor(part);
      expect(allowed.map((c) => c.serial), ['CUS-0001', 'CUS-0006']);
      expect(part.allowsCustom('CUS-0099'), isFalse);
    });
  });

  group('KinSaveStore.filterAllowed', () {
    late KinSaveStore store;
    late KinTemplate template;

    setUp(() {
      store = KinSaveStore();
      template = catalog.kinBySerial('KIN-BRZ-GEN001-0001')!;
    });

    test('keeps allowed customs and drops disallowed', () {
      final filtered = store.filterAllowed(
        template,
        catalog,
        const [
          KinAppliedCustom(
            partSerial: 'KPART-0001',
            customSerial: 'CUS-0001',
            value: 12.0,
          ),
          KinAppliedCustom(
            partSerial: 'KPART-0001',
            customSerial: 'CUS-0099',
            value: 1.0,
          ),
          KinAppliedCustom(
            partSerial: 'KPART-0002',
            customSerial: 'CUS-0006',
            value: 'KEMB-0001',
          ),
          KinAppliedCustom(
            partSerial: 'KPART-0001',
            customSerial: 'CUS-0006',
            value: 'KEMB-0099',
          ),
          KinAppliedCustom(
            partSerial: 'KPART-0001',
            customSerial: 'CUS-0006',
            value: 'KEMB-0001',
          ),
        ],
      );
      expect(filtered, hasLength(2));
      expect(filtered[0].customSerial, 'CUS-0001');
      expect(filtered[1].customSerial, 'CUS-0006');
      expect(filtered[1].value, 'KEMB-0001');
    });
  });

  group('KinSaveStore.save', () {
    test('writes sidecar + lottie and activates serial', () async {
      final temp = await Directory.systemTemp.createTemp('kin_save_test_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final memory = <String, String>{};
      final store = KinSaveStore(
        storage: _MemorySecureStorage(memory),
        documentsDirectory: () async => temp,
        httpClient: _FakeHttpClient(),
      );

      final draft = await store.save(
        template: catalog.kinBySerial('KIN-BRZ-GEN001-0001')!,
        catalog: catalog,
        applied: const [
          KinAppliedCustom(
            partSerial: 'KPART-0001',
            customSerial: 'CUS-0001',
            value: 30,
          ),
          KinAppliedCustom(
            partSerial: 'KPART-0001',
            customSerial: 'CUS-0099',
            value: 1,
          ),
        ],
        regionCode: 'EVG',
        colorHex: '#C6A15B',
        chosenName: 'My Genie',
      );

      expect(draft.serial, 'KSAVE-0001');
      expect(draft.kinSerial, 'KIN-BRZ-GEN001-0001');
      expect(draft.regionCode, 'EVG');
      expect(draft.colorHex, '#C6A15B');
      expect(draft.chosenName, 'My Genie');
      expect(draft.displayName, 'My Genie');
      expect(draft.applied, hasLength(1));
      expect(await store.readActiveSerial(), 'KSAVE-0001');

      final loaded = await store.readActiveDraft();
      expect(loaded?.serial, 'KSAVE-0001');
      expect(loaded?.regionCode, 'EVG');
      expect(loaded?.colorHex, '#C6A15B');
      expect(loaded?.chosenName, 'My Genie');
      expect(loaded?.applied.single.value, 30);

      final lottie = await store.lottieFileFor(draft);
      expect(lottie, isNotNull);
      expect(await lottie!.exists(), isTrue);
      final decoded = jsonDecode(await lottie.readAsString()) as Map;
      expect(decoded['nm'], contains('Bronze Genie'));
    });
  });

  group('KinCustomize allow-list behavior', () {
    test('part.allowsCustom gates unknown customs', () {
      final part = catalog.kinBySerial('KIN-BRZ-GEN001-0001')!.parts.first;
      expect(part.allowsCustom('CUS-0001'), isTrue);
      expect(part.allowsCustom('CUS-0099'), isFalse);
      expect(part.allowsEmbed('KEMB-0001'), isTrue);
      expect(part.allowsEmbed('KEMB-0099'), isFalse);
    });
  });
}

class _MemorySecureStorage implements FlutterSecureStorage {
  _MemorySecureStorage(this.map);

  final Map<String, String> map;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      map[key];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.empty(),
      404,
      request: request,
    );
  }
}
