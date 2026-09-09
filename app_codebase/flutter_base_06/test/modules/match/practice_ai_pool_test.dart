import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/match/practice_ai_pool.dart';

void main() {
  group('practiceAiPool', () {
    test('pool has exactly 2 distinct userIds', () {
      expect(practiceAiPoolUserIds, hasLength(2));
      expect(practiceAiPoolUserIds.toSet(), hasLength(2));
    });

    test('pickPracticeAiUserIds returns both pool members', () {
      final picked = pickPracticeAiUserIds(random: Random(7));
      expect(picked, hasLength(2));
      expect(picked[0], isNot(picked[1]));
      expect(picked.toSet(), practiceAiPoolUserIds.toSet());
    });

    test('pickPracticeAiUserIds is deterministic with seeded Random', () {
      final a = pickPracticeAiUserIds(random: Random(99));
      final b = pickPracticeAiUserIds(random: Random(99));
      expect(a, b);
    });
  });
}
