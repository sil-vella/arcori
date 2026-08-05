/// Wire + runtime models for match hot state.
library;

const stubArenaId = 'arena_velora_plaza';
const stubArcoriId = 'ANM-TIG-GEN001-0001';
const stubAiArcoriId = 'ANM-WTI-GEN001-0002';
const stubSlammerId = 'SLM-STR-GEN001-0001';

class MatchSeat {
  const MatchSeat({
    required this.userId,
    required this.seatIndex,
    required this.kind,
    required this.arcoriIds,
    required this.slammerId,
    this.score = 0,
    this.connected = true,
  });

  final String userId;
  final int seatIndex;
  final String kind; // human | ai
  final int score;
  final bool connected;
  final List<String> arcoriIds;
  final String slammerId;

  MatchSeat copyWith({
    int? score,
    bool? connected,
  }) {
    return MatchSeat(
      userId: userId,
      seatIndex: seatIndex,
      kind: kind,
      arcoriIds: arcoriIds,
      slammerId: slammerId,
      score: score ?? this.score,
      connected: connected ?? this.connected,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'userId': userId,
      'seatIndex': seatIndex,
      'kind': kind,
      'score': score,
      'connected': connected,
      'arcoriIds': List<String>.from(arcoriIds),
      'slammerId': slammerId,
    };
  }

  static MatchSeat fromPayload(Map<String, dynamic> payload) {
    final rawIds = payload['arcoriIds'];
    final arcoriIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : <String>[];
    return MatchSeat(
      userId: payload['userId']?.toString() ?? '',
      seatIndex: payload['seatIndex'] is int ? payload['seatIndex'] as int : 0,
      kind: payload['kind']?.toString() ?? 'human',
      score: payload['score'] is int ? payload['score'] as int : 0,
      connected: payload['connected'] != false,
      arcoriIds: arcoriIds,
      slammerId: payload['slammerId']?.toString() ?? '',
    );
  }
}

class MatchSnapshot {
  const MatchSnapshot({
    required this.matchId,
    required this.version,
    required this.phase,
    required this.round,
    required this.roundsTotal,
    required this.arenaId,
    required this.callerUserId,
    required this.matchType,
    required this.seats,
    this.table = const {'pieces': <dynamic>[]},
    this.active,
    this.lastEvent,
    this.result,
  });

  final String matchId;
  final int version;
  final String phase; // waiting | playing | ended
  final int round;
  final int roundsTotal;
  final String arenaId;
  final String callerUserId;
  final Map<String, dynamic> matchType;
  final List<MatchSeat> seats;
  final Map<String, dynamic> table;
  final Map<String, dynamic>? active;
  final Map<String, dynamic>? lastEvent;
  final Map<String, dynamic>? result;

  MatchSnapshot copyWith({
    int? version,
    String? phase,
    int? round,
    List<MatchSeat>? seats,
    Map<String, dynamic>? table,
    Map<String, dynamic>? active,
    Map<String, dynamic>? lastEvent,
    Map<String, dynamic>? result,
    bool clearActive = false,
    bool clearLastEvent = false,
    bool clearResult = false,
  }) {
    return MatchSnapshot(
      matchId: matchId,
      version: version ?? this.version,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      roundsTotal: roundsTotal,
      arenaId: arenaId,
      callerUserId: callerUserId,
      matchType: Map<String, dynamic>.from(matchType),
      seats: seats ?? this.seats,
      table: table ?? this.table,
      active: clearActive ? null : (active ?? this.active),
      lastEvent: clearLastEvent ? null : (lastEvent ?? this.lastEvent),
      result: clearResult ? null : (result ?? this.result),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'matchId': matchId,
      'version': version,
      'phase': phase,
      'round': round,
      'roundsTotal': roundsTotal,
      'arenaId': arenaId,
      'callerUserId': callerUserId,
      'matchType': Map<String, dynamic>.from(matchType),
      'seats': seats.map((s) => s.toPayload()).toList(),
      'table': Map<String, dynamic>.from(table),
      'active': active,
      'lastEvent': lastEvent,
      'result': result,
    };
  }

  static MatchSnapshot fromPayload(Map<String, dynamic> payload) {
    final rawSeats = payload['seats'];
    final seats = rawSeats is List
        ? rawSeats
            .whereType<Map>()
            .map((e) => MatchSeat.fromPayload(Map<String, dynamic>.from(e)))
            .toList()
        : <MatchSeat>[];
    final rawType = payload['matchType'];
    final matchType = rawType is Map
        ? Map<String, dynamic>.from(rawType)
        : <String, dynamic>{'code': 'practice'};
    final rawTable = payload['table'];
    return MatchSnapshot(
      matchId: payload['matchId']?.toString() ?? '',
      version: payload['version'] is int ? payload['version'] as int : 0,
      phase: payload['phase']?.toString() ?? 'waiting',
      round: payload['round'] is int ? payload['round'] as int : 1,
      roundsTotal:
          payload['roundsTotal'] is int ? payload['roundsTotal'] as int : 2,
      arenaId: payload['arenaId']?.toString() ?? stubArenaId,
      callerUserId: payload['callerUserId']?.toString() ?? '',
      matchType: matchType,
      seats: seats,
      table: rawTable is Map
          ? Map<String, dynamic>.from(rawTable)
          : const {'pieces': <dynamic>[]},
      active: payload['active'] is Map
          ? Map<String, dynamic>.from(payload['active'] as Map)
          : null,
      lastEvent: payload['lastEvent'] is Map
          ? Map<String, dynamic>.from(payload['lastEvent'] as Map)
          : null,
      result: payload['result'] is Map
          ? Map<String, dynamic>.from(payload['result'] as Map)
          : null,
    );
  }
}

/// Server-private freeze — not broadcast on the wire.
class MatchRuntime {
  MatchRuntime({
    required this.matchId,
    required this.frozenAt,
    required this.catalogById,
  });

  final String matchId;
  final DateTime frozenAt;
  final Map<String, Map<String, dynamic>> catalogById;
}
