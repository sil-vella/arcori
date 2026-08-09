import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/state/app_state_registry.dart';
import 'package:arcori/modules/match/practice_ai_pool.dart';
import 'package:arcori/modules/match/register_match_state.dart';
import 'package:arcori/modules/match/state/match_notifier.dart';
import 'package:arcori/modules/play/play_models.dart';

void main() {
  group('MatchSnapshotNotifier', () {
    test('local practice: pool AIs, empty AI loadout, slam rotate, end', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchSnapshotProvider.notifier);

      notifier.startLocalPractice(
        humanUserId: 'usr_local',
        loadout: const PracticeLoadout(
          arcoriId: 'ANM-TIG-GEN001-0001',
          slammerId: stubSlammerId,
        ),
        random: Random(1),
      );

      var snap = container.read(matchSnapshotProvider);
      expect(snap.seats, hasLength(3));
      expect(snap.matchType['code'], 'practice');
      expect(snap.active?['seatIndex'], 0);
      expect(practiceAiPoolUserIds, contains(snap.seats[1].userId));
      expect(practiceAiPoolUserIds, contains(snap.seats[2].userId));
      expect(snap.seats[1].arcoriIds, isEmpty);
      expect(snap.seats[1].slammerId, isEmpty);
      expect(snap.seats[2].arcoriIds, isEmpty);
      expect(snap.seats[2].slammerId, isEmpty);

      notifier.localSlam(actorUserId: 'usr_local');
      snap = container.read(matchSnapshotProvider);
      expect(snap.lastEvent?['type'], 'slam');
      expect(snap.active?['seatIndex'], 1);

      notifier.localEnd();
      snap = container.read(matchSnapshotProvider);
      expect(snap.isEnded, isTrue);
      expect(snap.active, isNull);
    });

    test('runLocalPracticeStubMatch: 6 stub slams then end', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchSnapshotProvider.notifier);
      final a = practiceAiPoolUserIds[0];
      final b = practiceAiPoolUserIds[1];

      final slamActors = <String>[];
      container.listen(matchSnapshotProvider, (prev, next) {
        final event = next.lastEvent;
        if (event == null || event['type'] != 'slam') return;
        if (prev?.lastEvent?['version'] == event['version']) return;
        slamActors.add(event['actorUserId'] as String);
      });

      notifier.startLocalPractice(
        humanUserId: 'usr_local',
        loadout: const PracticeLoadout(
          arcoriId: 'ANM-TIG-GEN001-0001',
          slammerId: stubSlammerId,
        ),
        aiUserIds: [a, b],
      );

      await notifier.runLocalPracticeStubMatch(stepDelay: Duration.zero);

      final snap = container.read(matchSnapshotProvider);
      expect(slamActors, [
        'usr_local',
        a,
        b,
        'usr_local',
        a,
        b,
      ]);
      expect(snap.isEnded, isTrue);
      expect(snap.round, 2);
      // start v1 + 6 slams + end
      expect(snap.version, 8);
      expect(snap.lastEvent?['type'], 'match_ended');
      expect(snap.result?['winnerUserIds'], ['usr_local']);
    });

    test('local practice accepts explicit aiUserIds', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(matchSnapshotProvider.notifier);
      final a = practiceAiPoolUserIds[0];
      final b = practiceAiPoolUserIds[1];

      notifier.startLocalPractice(
        humanUserId: 'usr_local',
        loadout: const PracticeLoadout(
          arcoriId: 'ANM-TIG-GEN001-0001',
          slammerId: stubSlammerId,
        ),
        aiUserIds: [a, b],
      );

      final snap = container.read(matchSnapshotProvider);
      expect(snap.seats[1].userId, a);
      expect(snap.seats[2].userId, b);
    });

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
