import 'package:test/test.dart';

import '../bin/modules/match/match_models.dart';
import '../bin/modules/match/match_store.dart';

void main() {
  group('MatchStore', () {
    late MatchStore store;

    setUp(() {
      store = MatchStore();
    });

    test('createPracticeStub freezes catalog and bumps on end', () {
      final catalog = {
        stubArcoriId: {
          'internalId': stubArcoriId,
          'catalogVersion': 1,
        },
        stubAiArcoriId: {
          'internalId': stubAiArcoriId,
          'catalogVersion': 1,
        },
        stubSlammerId: {
          'internalId': stubSlammerId,
          'gameplayAttributes': {'impact': 5},
          'catalogVersion': 1,
        },
      };

      final created = store.createPracticeStub(
        callerUserId: 'usr_caller',
        firstSeatIndex: 0,
        catalogById: catalog,
      );

      expect(created.version, 1);
      expect(created.phase, 'playing');
      expect(created.callerUserId, 'usr_caller');
      expect(created.matchType['code'], 'practice');
      expect(created.seats.length, 2);
      expect(created.seats[0].arcoriIds, [stubArcoriId]);
      expect(created.seats[0].slammerId, stubSlammerId);
      expect(created.seats[1].kind, 'ai');

      final runtime = store.getRuntime(created.matchId)!;
      expect(runtime.catalogById[stubSlammerId]!['gameplayAttributes']['impact'], 5);

      final ended = store.endMatch(created.matchId);
      expect(ended.version, 2);
      expect(ended.phase, 'ended');
      expect(ended.result, isNotNull);
      expect(ended.toPayload()['matchId'], created.matchId);
      expect(ended.seriesId, created.matchId);
      expect(ended.seriesIndex, 1);
      expect(ended.toPayload()['seriesId'], created.matchId);
      expect(ended.toPayload()['seriesIndex'], 1);
    });

    test('createFromLobby rematch mints series_NNN matchId', () {
      final catalog = {
        stubArcoriId: {
          'internalId': stubArcoriId,
          'catalogVersion': 1,
        },
        stubSlammerId: {
          'internalId': stubSlammerId,
          'gameplayAttributes': {'impact': 5},
          'catalogVersion': 1,
        },
      };
      const seriesRoot = 'm_65b0abc_123';
      final seats = [
        MatchSeat(
          userId: 'usr_a',
          seatIndex: 0,
          kind: 'human',
          arcoriIds: [stubArcoriId],
          slammerId: stubSlammerId,
        ),
        MatchSeat(
          userId: 'usr_b',
          seatIndex: 1,
          kind: 'human',
          arcoriIds: [stubArcoriId],
          slammerId: stubSlammerId,
        ),
      ];

      final rematch = store.createFromLobby(
        callerUserId: 'usr_a',
        matchType: {
          'code': 'invite',
          'subtype': 'inv_1',
          'rematch': true,
          'seriesId': seriesRoot,
          'seriesIndex': 2,
          'priorMatchId': seriesRoot,
        },
        seats: seats,
        catalogById: catalog,
        firstSeatIndex: 0,
      );

      expect(rematch.matchId, '${seriesRoot}_002');
      expect(rematch.seriesId, seriesRoot);
      expect(rematch.seriesIndex, 2);
      expect(rematch.toPayload()['seriesId'], seriesRoot);
      expect(rematch.toPayload()['seriesIndex'], 2);
    });

    test('createFromLobby opener stamps seriesId = matchId', () {
      final catalog = {
        stubArcoriId: {
          'internalId': stubArcoriId,
          'catalogVersion': 1,
        },
        stubSlammerId: {
          'internalId': stubSlammerId,
          'gameplayAttributes': {'impact': 5},
          'catalogVersion': 1,
        },
      };
      final created = store.createFromLobby(
        callerUserId: 'usr_a',
        matchType: const {'code': 'invite', 'subtype': 'inv_1'},
        seats: [
          MatchSeat(
            userId: 'usr_a',
            seatIndex: 0,
            kind: 'human',
            arcoriIds: [stubArcoriId],
            slammerId: stubSlammerId,
          ),
          MatchSeat(
            userId: 'usr_b',
            seatIndex: 1,
            kind: 'human',
            arcoriIds: [stubArcoriId],
            slammerId: stubSlammerId,
          ),
        ],
        catalogById: catalog,
        firstSeatIndex: 0,
      );
      expect(created.seriesId, created.matchId);
      expect(created.seriesIndex, 1);
      expect(created.matchId.startsWith('m_'), isTrue);
      expect(RegExp(r'_\d{3}$').hasMatch(created.matchId), isFalse);
    });
  });
}
