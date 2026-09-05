import 'package:test/test.dart';

import '../bin/core/errors/app_error.dart';
import '../bin/modules/match/action_dispatcher.dart';
import '../bin/modules/match/action_pack.dart';
import '../bin/modules/match/match_errors.dart';
import '../bin/modules/match/match_models.dart';
import '../bin/modules/match/match_store.dart';
import '../bin/modules/match/slam_input.dart';
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

    void clearAnimLock(String matchId) {
      final snap = store.getSnapshot(matchId);
      if (snap == null) return;
      final active = snap.active;
      if (active == null || !active.containsKey('inputLockedUntil')) return;
      store.bump(
        matchId,
        (s) => s.copyWith(active: activeWithoutAnimLock(active)),
      );
    }

    MatchSnapshot _practice() {
      return store.createPracticeStub(
        callerUserId: 'usr_a',
        firstSeatIndex: 0,
        catalogById: {
          stubArcoriId: {'internalId': stubArcoriId},
          stubAiArcoriId: {'internalId': stubAiArcoriId},
          stubSlammerId: {
            'internalId': stubSlammerId,
            'gameplayAttributes': {
              'impact': 5,
              'precision': 5,
              'control': 5,
              'recovery': 5,
              'spread': 5,
            },
          },
        },
      );
    }

    test('slam rejected during match start grace', () {
      final created = _practice();
      store.bump(created.matchId, (s) {
        return s.copyWith(
          active: {
            'seatIndex': 0,
            'action': 'slam',
            'graceEndsAt': DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 30))
                .toIso8601String(),
          },
        );
      });
      expect(
        () => dispatcher.dispatch(
          matchId: created.matchId,
          actorUserId: 'usr_a',
          payload: const {'action': 'slam'},
        ),
        throwsA(
          isA<AppError>().having((e) => e.code, 'code', matchNotYourTurn.code),
        ),
      );
    });

    test('slam echoes validated input on lastEvent', () {
      final created = _practice();
      expect(created.table['pieces'], isA<List>());
      expect((created.table['pieces'] as List), hasLength(2));
      final input = {
        'speed': 0.72,
        'aim': {'x': 0.0, 'z': 0.0}, 'trajectory': {'dx': 0.02, 'dy': 0.99, 'angleDeg': 88.8},
        'source': 'gesture',
      };
      final next = dispatcher.dispatch(
        matchId: created.matchId,
        actorUserId: 'usr_a',
        payload: {'action': 'slam', 'input': input},
      );
      expect(next.lastEvent?['input'], isNotNull);
      expect(next.lastEvent?['input']['speed'], 0.72);
      expect(next.lastEvent?['input']['source'], 'gesture');
      expect(next.lastEvent?['result'], anyOf('flip', 'miss'));
      expect(next.lastEvent?['outcome'], isNotNull);
      expect(next.lastEvent?['outcome']['impulse'], isNotNull);
    });

    test('slam rejects invalid input speed', () {
      final created = _practice();
      expect(
        () => dispatcher.dispatch(
          matchId: created.matchId,
          actorUserId: 'usr_a',
          payload: {
            'action': 'slam',
            'input': {
              'speed': 1.5,
              'aim': {'x': 0.0, 'z': 0.0}, 'trajectory': {'dx': 0, 'dy': 1},
            },
          },
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            matchInvalidRequest.code,
          ),
        ),
      );
    });

    test('core slam rotates active and keeps table pieces', () {
      final created = _practice();
      expect(created.matchType.containsKey('subtype'), isFalse);
      expect(created.active?['seatIndex'], 0);

      final next = dispatcher.dispatch(
        matchId: created.matchId,
        actorUserId: 'usr_a',
        payload: {
          'action': 'slam',
          'input': {
            'speed': 0.9,
            'aim': {'x': 0.0, 'z': 0.0}, 'trajectory': {'dx': 0.0, 'dy': 1.0},
            'source': 'gesture',
          },
        },
      );
      expect(next.version, 2);
      expect(next.lastEvent?['type'], 'slam');
      expect(next.lastEvent?['result'], anyOf('flip', 'miss'));
      expect(next.lastEvent?['seatIndex'], 0);
      expect(next.lastEvent?['round'], 1);
      expect(next.lastEvent?['slammerId'], stubSlammerId);
      expect(next.lastEvent?['arcoriId'], stubArcoriId);
      expect(next.active?['seatIndex'], 1);
      expect((next.table['pieces'] as List), hasLength(2));
    });

    test('slam wrapping advances round until roundsTotal', () {
      final created = _practice();
      // Practice stub: 2 seats (human + AI).
      expect(created.seats, hasLength(2));
      expect(created.roundsTotal, 2);

      dispatcher.dispatch(
        matchId: created.matchId,
        actorUserId: 'usr_a',
        payload: {'action': 'slam'},
      );
      clearAnimLock(created.matchId);
      final afterAi = dispatcher.dispatch(
        matchId: created.matchId,
        actorUserId: created.seats[1].userId,
        payload: {'action': 'slam'},
      );
      expect(afterAi.round, 2);
      expect(afterAi.active?['seatIndex'], 0);

      clearAnimLock(created.matchId);
      dispatcher.dispatch(
        matchId: created.matchId,
        actorUserId: 'usr_a',
        payload: {'action': 'slam'},
      );
      clearAnimLock(created.matchId);
      final last = dispatcher.dispatch(
        matchId: created.matchId,
        actorUserId: created.seats[1].userId,
        payload: {'action': 'slam'},
      );
      expect(last.round, 2);
      expect(last.lastEvent?['round'], 2);
      // Past last seat — turn runner must not timeout the same seat again.
      expect(last.active?['seatIndex'], 2);
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
        firstSeatIndex: 0,
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
