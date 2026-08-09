/// Lobby snapshot mirrored from Dart matchmaking/* broadcasts.
class LobbySnapshotState {
  const LobbySnapshotState({
    this.lobbyId,
    this.queueKey,
    this.phase,
    this.members = const [],
    this.targetSeats = 3,
    this.endsAt,
    this.matchId,
    this.matchType = const {},
  });

  final String? lobbyId;
  final String? queueKey;
  final String? phase;
  final List<Map<String, dynamic>> members;
  final int targetSeats;
  final DateTime? endsAt;
  final String? matchId;
  final Map<String, dynamic> matchType;

  bool get isWaiting => phase == 'waiting';
  bool get isPromoted => phase == 'promoted' || (matchId != null && matchId!.isNotEmpty);

  LobbySnapshotState copyWith({
    String? lobbyId,
    String? queueKey,
    String? phase,
    List<Map<String, dynamic>>? members,
    int? targetSeats,
    DateTime? endsAt,
    String? matchId,
    Map<String, dynamic>? matchType,
    bool clear = false,
  }) {
    if (clear) return const LobbySnapshotState();
    return LobbySnapshotState(
      lobbyId: lobbyId ?? this.lobbyId,
      queueKey: queueKey ?? this.queueKey,
      phase: phase ?? this.phase,
      members: members ?? this.members,
      targetSeats: targetSeats ?? this.targetSeats,
      endsAt: endsAt ?? this.endsAt,
      matchId: matchId ?? this.matchId,
      matchType: matchType ?? this.matchType,
    );
  }

  factory LobbySnapshotState.fromPayload(Map<String, dynamic> payload) {
    final rawMembers = payload['members'];
    final members = rawMembers is List
        ? rawMembers
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final rawType = payload['matchType'];
    DateTime? endsAt;
    final endsRaw = payload['endsAt']?.toString();
    if (endsRaw != null && endsRaw.isNotEmpty) {
      endsAt = DateTime.tryParse(endsRaw)?.toUtc();
    }
    return LobbySnapshotState(
      lobbyId: payload['lobbyId']?.toString(),
      queueKey: payload['queueKey']?.toString(),
      phase: payload['phase']?.toString(),
      members: members,
      targetSeats:
          payload['targetSeats'] is int ? payload['targetSeats'] as int : 3,
      endsAt: endsAt,
      matchId: payload['matchId']?.toString(),
      matchType: rawType is Map
          ? Map<String, dynamic>.from(rawType)
          : const <String, dynamic>{},
    );
  }
}
