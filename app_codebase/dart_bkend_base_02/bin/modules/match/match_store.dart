/// In-memory match snapshots + private catalog freeze per match.
library;

import 'dart:math';

import 'match_models.dart';

class MatchStore {
  final Map<String, MatchSnapshot> _snapshots = {};
  final Map<String, MatchRuntime> _runtimes = {};
  final _random = Random();

  void reset() {
    _snapshots.clear();
    _runtimes.clear();
  }

  MatchSnapshot? getSnapshot(String matchId) => _snapshots[matchId];

  MatchRuntime? getRuntime(String matchId) => _runtimes[matchId];

  Iterable<String> get matchIds => _snapshots.keys;

  String _newMatchId() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final n = _random.nextInt(1 << 20);
    return 'm_${stamp.toRadixString(16)}_$n';
  }

  /// Practice stub: human caller + one AI seat; freeze supplied by service.
  MatchSnapshot createPracticeStub({
    required String callerUserId,
    required Map<String, Map<String, dynamic>> catalogById,
    String arenaId = stubArenaId,
  }) {
    final matchId = _newMatchId();
    final seats = [
      MatchSeat(
        userId: callerUserId,
        seatIndex: 0,
        kind: 'human',
        arcoriIds: const [stubArcoriId],
        slammerId: stubSlammerId,
      ),
      const MatchSeat(
        userId: 'ai:seat_1',
        seatIndex: 1,
        kind: 'ai',
        arcoriIds: [stubAiArcoriId],
        slammerId: stubSlammerId,
      ),
    ];
    final snapshot = MatchSnapshot(
      matchId: matchId,
      version: 1,
      phase: 'playing',
      round: 1,
      roundsTotal: 2,
      arenaId: arenaId,
      callerUserId: callerUserId,
      matchType: const {'code': 'practice'},
      seats: seats,
    );
    _snapshots[matchId] = snapshot;
    _runtimes[matchId] = MatchRuntime(
      matchId: matchId,
      frozenAt: DateTime.now().toUtc(),
      catalogById: catalogById,
    );
    return snapshot;
  }

  MatchSnapshot bump(
    String matchId,
    MatchSnapshot Function(MatchSnapshot current) update,
  ) {
    final current = _snapshots[matchId];
    if (current == null) {
      throw StateError('match not found: $matchId');
    }
    final next = update(current);
    final bumped = next.copyWith(version: current.version + 1);
    _snapshots[matchId] = bumped;
    return bumped;
  }

  MatchSnapshot markConnected({
    required String matchId,
    required String userId,
    required bool connected,
  }) {
    return bump(matchId, (current) {
      final seats = current.seats.map((seat) {
        if (seat.userId != userId) return seat;
        return seat.copyWith(connected: connected);
      }).toList();
      return current.copyWith(seats: seats);
    });
  }

  MatchSnapshot endMatch(String matchId) {
    return bump(matchId, (current) {
      final scores = <String, int>{
        for (final seat in current.seats) seat.userId: seat.score,
      };
      final winnerUserIds = current.seats
          .where((s) => s.kind == 'human')
          .map((s) => s.userId)
          .toList();
      return current.copyWith(
        phase: 'ended',
        clearActive: true,
        lastEvent: {
          'type': 'match_ended',
          'actorUserId': null,
          'result': 'completed',
          'version': current.version + 1,
        },
        result: {
          'winnerUserIds': winnerUserIds,
          'finalScores': scores,
        },
      );
    });
  }

  void remove(String matchId) {
    _snapshots.remove(matchId);
    _runtimes.remove(matchId);
  }
}

final matchStore = MatchStore();

void resetMatchState() {
  matchStore.reset();
}
