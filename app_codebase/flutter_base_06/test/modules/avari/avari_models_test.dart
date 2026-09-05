import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/avari/avari_models.dart';
import 'package:arcori/modules/match/widgets/arcori_palette.dart';

void main() {
  group('AvariInventoryItem', () {
    test('parses access and slammers on profile', () {
      final profile = AvariProfile.fromJson({
        'identity': {
          'userId': 'u1',
          'displayName': 'Admin',
          'title': 'Avari',
          'accountType': 'Regular',
        },
        'access': [
          {
            'designId': 'ANM-TIG-GEN001-0001',
            'displayName': 'Tiger',
            'imageUrl': '/catalog-media/genesis/animals/ANM-TIG-GEN001-0001.webp',
            'color': '#C6A15B',
            'source': 'starter',
          },
        ],
        'slammers': [
          {
            'designId': 'SLM-STR-GEN001-0001',
            'displayName': 'Starter Slammer',
            'imageUrl': '/catalog-media/genesis/slammers/SLM-STR-GEN001-0001.webp',
            'color': '#C6A15B',
            'permanent': true,
            'source': 'starter',
          },
        ],
      });
      expect(profile.access, hasLength(1));
      expect(profile.access.first.displayName, 'Tiger');
      expect(profile.access.first.imageUrl, contains('ANM-TIG'));
      expect(profile.access.first.color, '#C6A15B');
      expect(profile.slammers.single.designId, 'SLM-STR-GEN001-0001');
      expect(profile.slammers.single.permanent, isTrue);
    });
  });

  group('parseCatalogColor', () {
    test('parses #RRGGBB', () {
      expect(parseCatalogColor('#C6A15B'), const Color(0xFFC6A15B));
    });

    test('null on empty', () {
      expect(parseCatalogColor(null), isNull);
      expect(parseCatalogColor(''), isNull);
    });
  });
}
