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
            'gameplayAttributes': {
              'impact': 5,
              'precision': 5,
              'control': 5,
              'recovery': 5,
              'spread': 5,
            },
          },
        ],
      });
      expect(profile.access, hasLength(1));
      expect(profile.access.first.displayName, 'Tiger');
      expect(profile.access.first.imageUrl, contains('ANM-TIG'));
      expect(profile.access.first.color, '#C6A15B');
      expect(profile.access.first.gameplayAttributes, isNull);
      expect(profile.slammers.single.designId, 'SLM-STR-GEN001-0001');
      expect(profile.slammers.single.permanent, isTrue);
      final attrs = profile.slammers.single.gameplayAttributes!;
      expect(attrs.impact, 5);
      expect(attrs.labeledValues, [
        ('Impact', 5),
        ('Precision', 5),
        ('Control', 5),
        ('Recovery', 5),
        ('Spread', 5),
      ]);
    });

    test('clamps gameplayAttributes to 1–10 and skips empty maps', () {
      final high = AvariInventoryItem.fromJson({
        'designId': 'SLM-X',
        'displayName': 'X',
        'gameplayAttributes': {'impact': 99, 'precision': 0},
      });
      expect(high.gameplayAttributes!.impact, 10);
      expect(high.gameplayAttributes!.precision, 1);

      final empty = AvariInventoryItem.fromJson({
        'designId': 'SLM-Y',
        'displayName': 'Y',
        'gameplayAttributes': {'impact': true},
      });
      expect(empty.gameplayAttributes, isNull);
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
