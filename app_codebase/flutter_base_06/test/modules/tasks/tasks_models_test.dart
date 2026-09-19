import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/tasks/tasks_models.dart';

void main() {
  group('TaskRewardConfig / TaskClaimReward', () {
    test('parses gold_fragments amount', () {
      final reward = TaskRewardConfig.fromJson({
        'kind': 'gold_fragments',
        'amount': 2,
      });
      expect(reward.kind, 'gold_fragments');
      expect(reward.amount, 2);
    });

    test('mystery_box defaults amount to 2', () {
      final reward = TaskRewardConfig.fromJson({'kind': 'mystery_box'});
      expect(reward.kind, 'mystery_box');
      expect(reward.amount, 2);
    });

    test('claim reward granted payload', () {
      final granted = TaskClaimReward.fromJson({
        'kind': 'gold_fragments',
        'amount': 2,
        'status': 'granted',
        'goldArcori': 20,
        'goldFragments': 2,
      });
      expect(granted.status, 'granted');
      expect(granted.amount, 2);
      expect(granted.goldFragments, 2);
    });
  });

  group('dailyCacheUiState', () {
    TaskCatalogEntry cacheEntry() => TaskCatalogEntry.fromJson({
          'id': 'daily_mystery_box',
          'name': 'Daily Cache',
          'section': 'tasks',
          'taskType': 'claim_gate',
          'params': {
            'requires_goal_ids': ['play_one_match', 'land_three_flips'],
          },
          'reward': {'kind': 'gold_fragments', 'amount': 2},
        });

    TasksProgressSnapshot snap({
      required bool playDone,
      required bool flipsDone,
      required bool cacheDone,
    }) {
      return TasksProgressSnapshot.fromJson({
        'revision': 'r1',
        'dayKey': '2026-09-19',
        'goals': [
          {
            'goalId': 'play_one_match',
            'featured': true,
            'completedToday': playDone,
            'target': 1,
          },
          {
            'goalId': 'land_three_flips',
            'featured': true,
            'completedToday': flipsDone,
            'target': 3,
          },
          {
            'goalId': 'daily_mystery_box',
            'taskType': 'claim_gate',
            'completedToday': cacheDone,
            'target': 1,
          },
        ],
      });
    }

    test('locked until featured complete', () {
      expect(
        dailyCacheUiState(
          entry: cacheEntry(),
          progress: snap(playDone: true, flipsDone: false, cacheDone: false),
        ),
        DailyCacheUiState.locked,
      );
    });

    test('ready when requirements met', () {
      expect(
        dailyCacheUiState(
          entry: cacheEntry(),
          progress: snap(playDone: true, flipsDone: true, cacheDone: false),
        ),
        DailyCacheUiState.ready,
      );
    });

    test('claimed when completedToday', () {
      expect(
        dailyCacheUiState(
          entry: cacheEntry(),
          progress: snap(playDone: true, flipsDone: true, cacheDone: true),
        ),
        DailyCacheUiState.claimed,
      );
    });
  });
}
