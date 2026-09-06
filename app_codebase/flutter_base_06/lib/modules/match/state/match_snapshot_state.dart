/// Wire match snapshot mirrored from Dart `match/*` broadcasts.
class MatchSeatView {
  const MatchSeatView({
    required this.userId,
    required this.seatIndex,
    required this.kind,
    required this.score,
    required this.connected,
    required this.arcoriIds,
    required this.slammerId,
  });

  final String userId;
  final int seatIndex;
  final String kind;
  final int score;
  final bool connected;
  final List<String> arcoriIds;
  final String slammerId;

  MatchSeatView copyWith({int? score}) {
    return MatchSeatView(
      userId: userId,
      seatIndex: seatIndex,
      kind: kind,
      score: score ?? this.score,
      connected: connected,
      arcoriIds: arcoriIds,
      slammerId: slammerId,
    );
  }

  factory MatchSeatView.fromJson(Map<String, dynamic> json) {
    final rawIds = json['arcoriIds'];
    return MatchSeatView(
      userId: json['userId']?.toString() ?? '',
      seatIndex: json['seatIndex'] is int ? json['seatIndex'] as int : 0,
      kind: json['kind']?.toString() ?? 'human',
      score: json['score'] is int ? json['score'] as int : 0,
      connected: json['connected'] != false,
      arcoriIds: rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : const <String>[],
      slammerId: json['slammerId']?.toString() ?? '',
    );
  }
}

class MatchPieceView {
  const MatchPieceView({
    required this.pieceId,
    required this.designId,
    required this.ownerUserId,
    required this.seatIndex,
    required this.faceUp,
    required this.stackIndex,
    this.imageUrl,
    this.color,
  });

  final String pieceId;
  final String designId;
  final String ownerUserId;
  final int seatIndex;
  final bool faceUp;
  final int stackIndex;
  final String? imageUrl;
  final String? color;

  factory MatchPieceView.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['imageUrl']?.toString().trim() ?? '';
    final color = json['color']?.toString().trim() ?? '';
    return MatchPieceView(
      pieceId: json['pieceId']?.toString() ?? '',
      designId: json['designId']?.toString() ?? '',
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      seatIndex: json['seatIndex'] is int ? json['seatIndex'] as int : 0,
      faceUp: json['faceUp'] == true,
      stackIndex: json['stackIndex'] is int ? json['stackIndex'] as int : 0,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      color: color.isNotEmpty ? color : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'pieceId': pieceId,
        'designId': designId,
        'ownerUserId': ownerUserId,
        'seatIndex': seatIndex,
        'faceUp': faceUp,
        'stackIndex': stackIndex,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        if (color != null && color!.isNotEmpty) 'color': color,
      };
}

class MatchSnapshotState {
  const MatchSnapshotState({
    this.matchId,
    this.version = 0,
    this.phase,
    this.round = 1,
    this.roundsTotal = 2,
    this.arenaId,
    this.arenaImageUrl,
    this.callerUserId,
    this.matchType = const {},
    this.seats = const [],
    this.firstSeatIndex = 0,
    this.table = const {'pieces': <dynamic>[]},
    this.active,
    this.result,
    this.lastEvent,
  });

  final String? matchId;
  final int version;
  final String? phase;
  final int round;
  final int roundsTotal;
  final String? arenaId;
  final String? arenaImageUrl;
  final String? callerUserId;
  final Map<String, dynamic> matchType;
  final List<MatchSeatView> seats;
  final int firstSeatIndex;
  final Map<String, dynamic> table;
  final Map<String, dynamic>? active;
  final Map<String, dynamic>? result;
  final Map<String, dynamic>? lastEvent;

  bool get isEnded => phase == 'ended';

  List<MatchPieceView> get pieces {
    final raw = table['pieces'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => MatchPieceView.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  MatchSnapshotState copyWith({
    String? matchId,
    int? version,
    String? phase,
    int? round,
    int? roundsTotal,
    String? arenaId,
    String? arenaImageUrl,
    String? callerUserId,
    Map<String, dynamic>? matchType,
    List<MatchSeatView>? seats,
    int? firstSeatIndex,
    Map<String, dynamic>? table,
    Map<String, dynamic>? active,
    Map<String, dynamic>? result,
    Map<String, dynamic>? lastEvent,
    bool clear = false,
    bool clearActive = false,
  }) {
    if (clear) {
      return const MatchSnapshotState();
    }
    return MatchSnapshotState(
      matchId: matchId ?? this.matchId,
      version: version ?? this.version,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      roundsTotal: roundsTotal ?? this.roundsTotal,
      arenaId: arenaId ?? this.arenaId,
      arenaImageUrl: arenaImageUrl ?? this.arenaImageUrl,
      callerUserId: callerUserId ?? this.callerUserId,
      matchType: matchType ?? this.matchType,
      seats: seats ?? this.seats,
      firstSeatIndex: firstSeatIndex ?? this.firstSeatIndex,
      table: table ?? this.table,
      active: clearActive ? null : (active ?? this.active),
      result: result ?? this.result,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }

  factory MatchSnapshotState.fromPayload(Map<String, dynamic> payload) {
    final rawSeats = payload['seats'];
    final seats = rawSeats is List
        ? rawSeats
            .whereType<Map>()
            .map((e) => MatchSeatView.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MatchSeatView>[];
    final rawType = payload['matchType'];
    final rawTable = payload['table'];
    final firstRaw = payload['firstSeatIndex'];
    return MatchSnapshotState(
      matchId: payload['matchId']?.toString(),
      version: payload['version'] is int ? payload['version'] as int : 0,
      phase: payload['phase']?.toString(),
      round: payload['round'] is int ? payload['round'] as int : 1,
      roundsTotal:
          payload['roundsTotal'] is int ? payload['roundsTotal'] as int : 2,
      arenaId: payload['arenaId']?.toString(),
      arenaImageUrl: () {
        final raw = payload['arenaImageUrl']?.toString().trim() ?? '';
        return raw.isEmpty ? null : raw;
      }(),
      callerUserId: payload['callerUserId']?.toString(),
      matchType: rawType is Map
          ? Map<String, dynamic>.from(rawType)
          : const <String, dynamic>{},
      seats: seats,
      firstSeatIndex: firstRaw is int ? firstRaw : 0,
      table: rawTable is Map
          ? Map<String, dynamic>.from(rawTable)
          : const {'pieces': <dynamic>[]},
      active: payload['active'] is Map
          ? Map<String, dynamic>.from(payload['active'] as Map)
          : null,
      result: payload['result'] is Map
          ? Map<String, dynamic>.from(payload['result'] as Map)
          : null,
      lastEvent: payload['lastEvent'] is Map
          ? Map<String, dynamic>.from(payload['lastEvent'] as Map)
          : null,
    );
  }
}
