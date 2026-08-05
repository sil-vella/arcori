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
    });
  });
}
