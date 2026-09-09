/// In-memory match snapshots + private catalog freeze per match.
library;

import 'dart:math';

import 'match_models.dart';
import 'table_pieces.dart';
import 'type_subtype_pack_registry.dart';

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

  /// Rematch match ids: `{seriesRoot}_{NNN}` (3-digit, zero-padded). Index 1 = root.
  static String seriesMatchId({
    required String seriesId,
    required int seriesIndex,
  }) {
    final root = seriesId.trim();
    if (root.isEmpty) {
      throw ArgumentError('seriesId required');
    }
    if (seriesIndex <= 1) return root;
    return '${root}_${seriesIndex.toString().padLeft(3, '0')}';
  }

  static bool _isRematchMatchType(Map<String, dynamic> matchType) {
    final raw = matchType['rematch'];
    return raw == true || raw?.toString() == 'true';
  }

  /// Practice: human caller + AI seat; [matchType] has `code: practice` and no subtype.
  MatchSnapshot createPracticeStub({
    required String callerUserId,
    required Map<String, Map<String, dynamic>> catalogById,
    String arenaId = stubArenaId,
    String? arenaImageUrl,
    List<String>? callerArcoriIds,
    String? callerSlammerId,
    String aiArcoriId = stubAiArcoriId,
    String aiSlammerId = stubSlammerId,
    int? firstSeatIndex,
    Random? random,
  }) {
    final humanArcori = (callerArcoriIds != null && callerArcoriIds.isNotEmpty)
        ? List<String>.from(callerArcoriIds)
        : <String>[stubArcoriId];
    final humanSlammer =
        (callerSlammerId != null && callerSlammerId.trim().isNotEmpty)
            ? callerSlammerId.trim()
            : stubSlammerId;

    final matchId = _newMatchId();
    final seats = [
      MatchSeat(
        userId: callerUserId,
        seatIndex: 0,
        kind: 'human',
        arcoriIds: humanArcori,
        slammerId: humanSlammer,
      ),
      MatchSeat(
        userId: 'ai:seat_1',
        seatIndex: 1,
        kind: 'ai',
        arcoriIds: [aiArcoriId],
        slammerId: aiSlammerId,
      ),
    ];
    final first = firstSeatIndex ??
        (seats.length <= 1
            ? 0
            : (random ?? _random).nextInt(seats.length));
    final snapshot = MatchSnapshot(
      matchId: matchId,
      version: 1,
      phase: 'playing',
      round: 1,
      roundsTotal: 2,
      arenaId: arenaId,
      arenaImageUrl: arenaImageUrl,
      callerUserId: callerUserId,
      // Practice: no subtype key.
      matchType: const {'code': 'practice'},
      seats: seats,
      firstSeatIndex: first,
      seriesId: matchId,
      seriesIndex: 1,
      table: tableFromSeats(seats, catalogById: catalogById),
      active: {
        'seatIndex': first,
        'action': 'slam',
      },
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

  /// Online match from lobby: humans + AI seats; [matchType] carries game type.
  ///
  /// Rematch (`matchType.rematch == true`): mints `{seriesId}_{NNN}` instead of
  /// a fresh random id. Non-rematch openers set `seriesId = matchId`, index 1.
  MatchSnapshot createFromLobby({
    required String callerUserId,
    required Map<String, dynamic> matchType,
    required List<MatchSeat> seats,
    required Map<String, Map<String, dynamic>> catalogById,
    String arenaId = stubArenaId,
    String? arenaImageUrl,
    int? firstSeatIndex,
    Random? random,
  }) {
    if (seats.isEmpty) {
      throw ArgumentError('seats required');
    }

    final rematch = _isRematchMatchType(matchType);
    late final String matchId;
    late final String seriesId;
    late final int seriesIndex;

    if (rematch) {
      final rawSeries = matchType['seriesId']?.toString().trim() ?? '';
      final rawIndex = matchType['seriesIndex'];
      final index = rawIndex is int
          ? rawIndex
          : int.tryParse(rawIndex?.toString() ?? '') ?? 0;
      if (rawSeries.isEmpty || index < 2) {
        throw ArgumentError(
          'rematch requires seriesId and seriesIndex >= 2',
        );
      }
      seriesId = rawSeries;
      seriesIndex = index;
      matchId = seriesMatchId(seriesId: seriesId, seriesIndex: seriesIndex);
      if (_snapshots.containsKey(matchId)) {
        throw StateError('rematch matchId already exists: $matchId');
      }
    } else {
      matchId = _newMatchId();
      seriesId = matchId;
      seriesIndex = 1;
    }

    final first = firstSeatIndex ??
        (seats.length <= 1
            ? 0
            : (random ?? _random).nextInt(seats.length));
    final snapshot = MatchSnapshot(
      matchId: matchId,
      version: 1,
      phase: 'playing',
      round: 1,
      roundsTotal: 2,
      arenaId: arenaId,
      arenaImageUrl: arenaImageUrl,
      callerUserId: callerUserId,
      matchType: Map<String, dynamic>.from(matchType),
      seats: seats,
      firstSeatIndex: first,
      seriesId: seriesId,
      seriesIndex: seriesIndex,
      table: tableFromSeats(seats, catalogById: catalogById),
      active: {
        'seatIndex': first,
        'action': 'slam',
      },
    );
    _snapshots[matchId] = snapshot;
    _runtimes[matchId] = MatchRuntime(
      matchId: matchId,
      frozenAt: DateTime.now().toUtc(),
      catalogById: catalogById,
    );
    return snapshot;
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
  typeSubtypePackRegistry.clear();
}
