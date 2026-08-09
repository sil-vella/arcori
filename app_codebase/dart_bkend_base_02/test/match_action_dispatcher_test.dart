import 'package:test/test.dart';

import '../bin/core/errors/app_error.dart';
import '../bin/modules/match/action_dispatcher.dart';
import '../bin/modules/match/action_pack.dart';
import '../bin/modules/match/match_errors.dart';
import '../bin/modules/match/match_models.dart';
import '../bin/modules/match/match_store.dart';
import '../bin/modules/match/type_subtype_pack_registry.dart';

void main() {
  group('ActionDispatcher', () {
    late MatchStore store;
    late ActionDispatcher dispatcher;
    late TypeSubtypePackRegistry packs;

    setUp(() {
      store = MatchStore();
      packs = TypeSubtypePackRegistry();
      dispatcher = ActionDispatcher(store: store, packs: packs);
    });

    MatchSnapshot _practice() {
      return store.createPracticeStub(
        callerUserId: 'usr_a',
        catalogById: {
          stubArcoriId: {'internalId': stubArcoriId},
          stubAiArcoriId: {'internalId': stubAiArcoriId},
          stubSlammerId: {'internalId': stubSlammerId},
        },
      );
    }

    test('core slam stubs lastEvent and rotates active', () {
      final created = _practice();
      expect(created.matchType.containsKey('subtype'), isFalse);
      expect(created.active?['seatIndex'], 0);

      final next = dispatcher.dispatch(
        matchId: created.matchId,
        actorUserId: 'usr_a',
        payload: {'action': 'slam'},
      );
      expect(next.version, 2);
      expect(next.lastEvent?['type'], 'slam');
      expect(next.lastEvent?['result'], 'stub');
      expect(next.active?['seatIndex'], 1);
    });

    test('unknown action fails', () {
      final created = _practice();
      expect(
        () => dispatcher.dispatch(
          matchId: created.matchId,
          actorUserId: 'usr_a',
          payload: {'action': 'royal_claim'},
        ),
        throwsA(
          isA<AppError>().having((e) => e.code, 'code', matchInvalidAction.code),
        ),
      );
    });

    test('type/subtype pack handles extra action without touching core', () {
      packs.register(
        'specialEvent',
        subtype: 'royal-battle',
        pack: _FakeRoyalPack(),
      );
      final created = store.createPracticeStub(
        callerUserId: 'usr_a',
        catalogById: {
          stubArcoriId: {'internalId': stubArcoriId},
          stubAiArcoriId: {'internalId': stubAiArcoriId},
          stubSlammerId: {'internalId': stubSlammerId},
        },
      );
      // Force matchType to event for this test by bumping.
      store.bump(created.matchId, (s) {
        return s.copyWith(
          matchType: const {
            'code': 'specialEvent',
            'subtype': 'royal-battle',
          },
        );
      });

      final next = dispatcher.dispatch(
        matchId: created.matchId,
        actorUserId: 'usr_a',
        payload: {'action': 'royal_claim'},
      );
      expect(next.lastEvent?['type'], 'royal_claim');
    });

    test('not your turn when active seat differs', () {
      final created = _practice();
      store.bump(created.matchId, (s) {
        return s.copyWith(active: {'seatIndex': 1, 'action': 'slam'});
      });
      expect(
        () => dispatcher.dispatch(
          matchId: created.matchId,
          actorUserId: 'usr_a',
          payload: {'action': 'slam'},
        ),
        throwsA(
          isA<AppError>().having((e) => e.code, 'code', matchNotYourTurn.code),
        ),
      );
    });
  });
}

class _FakeRoyalPack implements MatchActionPack {
  @override
  Set<String> get actionNames => const {'royal_claim'};

  @override
  MatchActionHandler? handlerFor(String action) {
    if (action != 'royal_claim') return null;
    return ({
      required MatchStore store,
      required MatchSnapshot current,
      required String actorUserId,
      required Map<String, dynamic> payload,
    }) {
      return store.bump(current.matchId, (s) {
        return s.copyWith(
          lastEvent: {
            'type': 'royal_claim',
            'actorUserId': actorUserId,
            'result': 'stub',
          },
        );
      });
    };
  }
}
