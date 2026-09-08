import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/kin/kin_catalog_loader.dart';
import 'package:arcori/modules/kin/kin_models.dart';
import 'package:arcori/modules/kin/kin_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads bundled Kin catalogs from assets', () async {
    final catalog = await KinCatalogLoader().load();
    expect(catalog.types, isNotEmpty);
    expect(catalog.kins, isNotEmpty);
    expect(catalog.customs, isNotEmpty);
    expect(catalog.embeds, isNotEmpty);
    expect(catalog.customTypes, isNotEmpty);

    final guardiansType = catalog.typeBySerial('KTYPE-0001');
    expect(guardiansType?.code, 'guardians');
    final bronze = catalog.kinBySerial('KIN-BRZ-GEN001-0001');
    expect(bronze?.typeSerial, 'KTYPE-0001');
    expect(bronze?.parts, isNotEmpty);
    expect(
      bronze?.lottieUrl,
      '/catalog-media/kin/gen001/guardians/KIN-BRZ-GEN001-0001.json',
    );
    final guardianKins = catalog.kinsForType('KTYPE-0001');
    expect(
      guardianKins.map((k) => k.serial),
      containsAll(['KIN-BRZ-GEN001-0001', 'KIN-GLD-GEN001-0002', 'KIN-IVY-GEN001-0003', 'KIN-SLV-GEN001-0004']),
    );
    expect(catalog.kinsForType('KTYPE-0002'), hasLength(4));
    expect(catalog.kinsForType('KTYPE-0003'), hasLength(9));
    expect(catalog.kins, hasLength(17));
  });

  test('customize notifier rejects disallowed customs', () {
    final catalog = KinCreationCatalog(
      customTypes: const [],
      customs: [
        KinCustom.fromJson({
          'serial': 'CUS-0001',
          'customType': 'hue',
          'displayName': 'Hue',
          'params': {'default': 0},
        }),
        KinCustom.fromJson({
          'serial': 'CUS-0099',
          'customType': 'hue',
          'displayName': 'Blocked',
          'params': {'default': 0},
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
              'allowedCustomSerials': ['CUS-0001'],
              'embedPoolSerials': [],
            },
          ],
        }),
      ],
    );
    final notifier = KinCustomizeNotifier(
      kinSerial: 'KIN-BRZ-GEN001-0001',
      catalog: catalog,
    );
    expect(
      notifier.applyCustom(
        partSerial: 'KPART-0001',
        customSerial: 'CUS-0001',
        value: 10,
      ),
      isTrue,
    );
    expect(
      notifier.applyCustom(
        partSerial: 'KPART-0001',
        customSerial: 'CUS-0099',
        value: 10,
      ),
      isFalse,
    );
    expect(notifier.state.toAppliedList(), hasLength(1));
  });
}
