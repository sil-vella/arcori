import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/avari/avari_models.dart';
import 'package:arcori/modules/match/widgets/arcori_palette.dart';

void main() {
  group('AvariInventoryItem', () {
    test('parses masteryPoints and mintReach on access', () {
      final item = AvariInventoryItem.fromJson({
        'designId': 'ANM-TIG-SER001-0001',
        'displayName': 'Tiger',
        'masteryPoints': 7,
        'mintReach': 500,
      });
      expect(item.masteryPoints, 7);
      expect(item.mintReach, 500);
      expect(item.masteryOverMintReach, '7/500');
    });

    test('parses economy wallet', () {
      final profile = AvariProfile.fromJson({
        'identity': {
          'userId': 'u1',
          'displayName': 'Admin',
          'title': 'Avari',
          'accountType': 'Regular',
        },
        'economy': {
          'goldArcori': 20,
          'goldFragments': 3,
        },
      });
      expect(profile.economy.goldArcori, 20);
      expect(profile.economy.goldFragments, 3);
    });

    test('economy defaults when missing', () {
      final profile = AvariProfile.fromJson({
        'identity': {
          'userId': 'u1',
          'displayName': 'Admin',
          'title': 'Avari',
          'accountType': 'Regular',
        },
      });
      expect(profile.economy.goldArcori, 0);
      expect(profile.economy.goldFragments, 0);
    });

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
            'designId': 'ANM-TIG-SER001-0001',
            'displayName': 'Tiger',
            'imageUrl': '/catalog-media/001_genesis/animals/ANM-TIG-SER001-0001.webp',
            'color': '#C6A15B',
            'source': 'starter',
          },
        ],
        'slammers': [
          {
            'designId': 'SLM-STR-SER001-0001',
            'displayName': 'Starter Slammer',
            'imageUrl': '/catalog-media/001_genesis/slammers/SLM-STR-SER001-0001.webp',
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
      expect(profile.access.first.masteryPoints, 0);
      expect(profile.access.first.gameplayAttributes, isNull);
      expect(profile.slammers.single.designId, 'SLM-STR-SER001-0001');
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

    test('parses lottie face on access', () {
      final item = AvariInventoryItem.fromJson({
        'designId': 'KIN-X-SER001-0001',
        'displayName': 'Admin',
        'lottieUrl': '/media/kin/players/KIN-X-SER001-0001.json',
        'faceMedia': 'lottie',
        'masteryPoints': 0,
        'mintReach': 500,
        'background': {'theme': 'SOLID', 'colorHex': '#222222'},
      });
      expect(item.hasLottieFace, isTrue);
      expect(item.lottieUrl, contains('kin/players'));
      expect(item.background?['colorHex'], '#222222');
      expect(item.masteryOverMintReach, '0/500');
    });
  });

  group('MatchFinalizeResult', () {
    test('parses masteryChanges with new level and face fields', () {
      final result = MatchFinalizeResult.fromJson({
        'applied': true,
        'reason': 'economy',
        'matchId': 'm1',
        'masteryChanges': [
          {
            'designId': 'ANM-TIG-SER001-0001',
            'delta': 2,
            'pointsBefore': 1,
            'pointsAfter': 3,
            'flips': 2,
            'kind': 'own',
            'mintReach': 500,
            'displayName': 'Tiger',
            'imageUrl': '/catalog-media/x.webp',
            'color': '#C6A15B',
          },
        ],
      });
      expect(result.masteryChanges, hasLength(1));
      final c = result.masteryChanges.single;
      expect(c.pointsAfter, 3);
      expect(c.masteryOverMintReach, '3/500');
      expect(c.relativeDeltaLabel, '+2');
      expect(c.displayName, 'Tiger');
      expect(c.flips, 2);
    });
  });

  group('AvariKin', () {
    test('parses kin masteryPoints and mintReach', () {
      final kin = AvariKin.fromJson({
        'subtheme': 'Entelairs',
        'style': 'Chibi',
        'finish': 'Standard',
        'effect': 'None',
        'genesisDesignId': 'KIN-X-SER001-0001',
        'chosenName': 'Admin',
        'masteryPoints': 4,
        'mintReach': 500,
      });
      expect(kin.masteryPoints, 4);
      expect(kin.mintReach, 500);
      expect(kin.masteryOverMintReach, '4/500');
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
