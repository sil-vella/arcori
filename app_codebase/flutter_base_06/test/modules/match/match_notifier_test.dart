import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/state/app_state_registry.dart';
import 'package:arcori/modules/match/register_match_state.dart';
import 'package:arcori/modules/match/state/match_notifier.dart';

void main() {
  group('MatchSnapshotNotifier', () {
    test('applies snapshot and ignores older version', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchSnapshotProvider.notifier);

      notifier.applyWsFrame({
        'channel': 'match/create',
        'payload': {
          'matchId': 'm_1',
          'version': 2,
          'phase': 'playing',
          'round': 1,
          'roundsTotal': 2,
          'arenaId': 'arena_velora_plaza',
          'callerUserId': 'usr_a',
          'matchType': {'code': 'practice'},
          'seats': [
            {
              'userId': 'usr_a',
              'seatIndex': 0,
              'kind': 'human',
              'score': 0,
              'connected': true,
              'arcoriIds': ['ANM-TIG-GEN001-0001'],
              'slammerId': 'SLM-STR-GEN001-0001',
            },
          ],
          'table': {'pieces': []},
          'active': null,
          'lastEvent': null,
          'result': null,
        },
      });

      expect(container.read(matchSnapshotProvider).matchId, 'm_1');
      expect(container.read(matchSnapshotProvider).version, 2);
      expect(container.read(matchSnapshotProvider).phase, 'playing');

      notifier.applyWsFrame({
        'channel': 'match/state',
        'payload': {
          'matchId': 'm_1',
          'version': 1,
          'phase': 'playing',
          'callerUserId': 'usr_a',
          'matchType': {'code': 'practice'},
          'seats': [],
        },
      });
      expect(container.read(matchSnapshotProvider).version, 2);
    });

    test('registered handler updates via replay', () {
      resetAppStateRegistry();
      registerMatchState(appStateSink);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      late Ref ref;
      container.read(Provider((r) {
        ref = r;
        return 0;
      }));

      container.read(matchSnapshotProvider);

      final router = buildWsChannelRouter(ref);
      router.dispatch('dart', {
        'channel': 'match/end',
        'payload': {
          'matchId': 'm_2',
          'version': 3,
          'phase': 'ended',
          'callerUserId': 'usr_a',
          'matchType': {'code': 'practice'},
          'seats': [],
          'result': {
            'winnerUserIds': ['usr_a'],
            'finalScores': {'usr_a': 0},
          },
        },
      });

      expect(container.read(matchSnapshotProvider).isEnded, isTrue);
      expect(container.read(matchSnapshotProvider).matchId, 'm_2');
    });
  });
}
