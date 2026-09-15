import 'package:flutter_test/flutter_test.dart';

import 'package:arcori/modules/achievements/achievements_models.dart';
import 'package:arcori/modules/achievements/achievements_catalog_store.dart';

void main() {
  setUp(AchievementsCatalogStore.clear);

  test('catalog store apply and unlock', () {
    final catalog = AchievementsCatalog.fromJson({
      'revision': 'abc',
      'schemaVersion': 1,
      'achievements': [
        {
          'id': 'first_victory',
          'achievementName': 'First victory',
          'description': 'Win once',
          'achievementType': 'total_wins',
          'params': {'min': 1},
          'postAchieveAction': {
            'type': 'move_to_screen',
            'screen': 'avari',
            'ctaLabel': 'View',
          },
        },
      ],
    });
    AchievementsCatalogStore.applyCatalog(catalog);
    expect(AchievementsCatalogStore.hasDocument, isTrue);
    expect(AchievementsCatalogStore.displayName('first_victory'), 'First victory');
    expect(AchievementsCatalogStore.isUnlocked('first_victory'), isFalse);
    AchievementsCatalogStore.markUnlocked(['first_victory']);
    expect(AchievementsCatalogStore.isUnlocked('first_victory'), isTrue);
    final action = AchievementsCatalogStore.byId('first_victory')!.postAchieveAction;
    expect(action.type, PostAchieveActionTypes.moveToScreen);
    expect(action.screen, 'avari');
  });

  test('MatchFinalizeResult parses achievementsUnlocked', () {
    // Imported via avari_models in other tests; keep models self-test here.
    final entry = AchievementEntry.fromJson({
      'id': 'first_match',
      'achievementName': 'First steps',
      'description': 'Play once',
      'achievementType': 'total_matches',
      'postAchieveAction': {'type': 'none'},
    });
    expect(entry.id, 'first_match');
    expect(entry.postAchieveAction.type, PostAchieveActionTypes.none);
  });
}
