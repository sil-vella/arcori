/// Lobby models for Quick Join / Special Event matchmaking.
library;

class LobbyMember {
  const LobbyMember({
    required this.userId,
    required this.connectionId,
    this.arcoriIds = const [],
    this.slammerId = '',
  });

  final String userId;
  final String connectionId;
  final List<String> arcoriIds;
  final String slammerId;

  Map<String, dynamic> toPayload() => {
        'userId': userId,
        'connectionId': connectionId,
        'arcoriIds': List<String>.from(arcoriIds),
        'slammerId': slammerId,
      };
}

class LobbySnapshot {
  const LobbySnapshot({
    required this.lobbyId,
    required this.queueKey,
    required this.matchType,
    required this.phase,
    required this.members,
    required this.targetSeats,
    required this.endsAt,
    this.matchId,
  });

  final String lobbyId;
  final String queueKey;
  final Map<String, dynamic> matchType;
  final String phase; // waiting | promoted | cancelled
  final List<LobbyMember> members;
  final int targetSeats;
  final DateTime endsAt;
  final String? matchId;

  LobbySnapshot copyWith({
    String? phase,
    List<LobbyMember>? members,
    DateTime? endsAt,
    String? matchId,
    bool clearMatchId = false,
  }) {
    return LobbySnapshot(
      lobbyId: lobbyId,
      queueKey: queueKey,
      matchType: Map<String, dynamic>.from(matchType),
      phase: phase ?? this.phase,
      members: members ?? this.members,
      targetSeats: targetSeats,
      endsAt: endsAt ?? this.endsAt,
      matchId: clearMatchId ? null : (matchId ?? this.matchId),
    );
  }

  Map<String, dynamic> toPayload() => {
        'lobbyId': lobbyId,
        'queueKey': queueKey,
        'matchType': Map<String, dynamic>.from(matchType),
        'phase': phase,
        'members': members.map((m) => m.toPayload()).toList(),
        'targetSeats': targetSeats,
        'endsAt': endsAt.toUtc().toIso8601String(),
        'matchId': matchId,
      };
}

/// Build queue key that separates Quick Join vs Special Event lobbies.
String queueKeyFor(Map<String, dynamic> matchType) {
  final code = matchType['code']?.toString().trim() ?? '';
  final subtype = matchType['subtype']?.toString().trim() ?? '';
  final eventId = matchType['eventId']?.toString().trim() ?? '';
  return '$code|$subtype|$eventId';
}

Map<String, dynamic> parseMatchType(Map<String, dynamic> payload) {
  final raw = payload['matchType'];
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final code = map['code']?.toString().trim() ?? '';
    if (code.isEmpty) {
      throw ArgumentError('matchType.code required');
    }
    return map;
  }
  final code = payload['code']?.toString().trim() ?? '';
  if (code.isEmpty) {
    throw ArgumentError('matchType.code required');
  }
  final out = <String, dynamic>{'code': code};
  final subtype = payload['subtype']?.toString().trim();
  if (subtype != null && subtype.isNotEmpty) out['subtype'] = subtype;
  final eventId = payload['eventId']?.toString().trim();
  if (eventId != null && eventId.isNotEmpty) out['eventId'] = eventId;
  return out;
}
