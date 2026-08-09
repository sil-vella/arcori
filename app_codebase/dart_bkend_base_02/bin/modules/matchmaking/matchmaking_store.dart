/// In-memory open lobbies indexed by queueKey.
library;

import 'dart:math';

import 'matchmaking_models.dart';

const int defaultTargetSeats = 3;

class MatchmakingStore {
  final Map<String, LobbySnapshot> _lobbies = {};
  final Map<String, String> _userLobby = {}; // userId -> lobbyId
  final Map<String, List<String>> _openByKey = {}; // queueKey -> lobbyIds
  final _random = Random();

  void reset() {
    _lobbies.clear();
    _userLobby.clear();
    _openByKey.clear();
  }

  LobbySnapshot? getLobby(String lobbyId) => _lobbies[lobbyId];

  LobbySnapshot? lobbyForUser(String userId) {
    final id = _userLobby[userId];
    if (id == null) return null;
    return _lobbies[id];
  }

  String _newLobbyId() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final n = _random.nextInt(1 << 20);
    return 'lobby_${stamp.toRadixString(16)}_$n';
  }

  /// First waiting, not-full lobby for [queueKey] whose timer has not expired.
  LobbySnapshot? findOpenLobby(String queueKey, {DateTime? now}) {
    final ids = _openByKey[queueKey];
    if (ids == null || ids.isEmpty) return null;
    final clock = now ?? DateTime.now().toUtc();
    for (final id in List<String>.from(ids)) {
      final lobby = _lobbies[id];
      if (lobby == null || lobby.phase != 'waiting') {
        ids.remove(id);
        continue;
      }
      if (lobby.members.length >= lobby.targetSeats) continue;
      if (!lobby.endsAt.isAfter(clock)) continue;
      return lobby;
    }
    return null;
  }

  LobbySnapshot createLobby({
    required Map<String, dynamic> matchType,
    required LobbyMember creator,
    required DateTime endsAt,
    int targetSeats = defaultTargetSeats,
  }) {
    final queueKey = queueKeyFor(matchType);
    final lobbyId = _newLobbyId();
    final lobby = LobbySnapshot(
      lobbyId: lobbyId,
      queueKey: queueKey,
      matchType: matchType,
      phase: 'waiting',
      members: [creator],
      targetSeats: targetSeats,
      endsAt: endsAt.toUtc(),
    );
    _lobbies[lobbyId] = lobby;
    _userLobby[creator.userId] = lobbyId;
    _openByKey.putIfAbsent(queueKey, () => []).add(lobbyId);
    return lobby;
  }

  LobbySnapshot addMember(String lobbyId, LobbyMember member) {
    final current = _lobbies[lobbyId];
    if (current == null) {
      throw StateError('lobby not found: $lobbyId');
    }
    if (current.members.any((m) => m.userId == member.userId)) {
      return current;
    }
    final next = current.copyWith(
      members: [...current.members, member],
    );
    _lobbies[lobbyId] = next;
    _userLobby[member.userId] = lobbyId;
    return next;
  }

  LobbySnapshot removeMember(String lobbyId, String userId) {
    final current = _lobbies[lobbyId];
    if (current == null) {
      throw StateError('lobby not found: $lobbyId');
    }
    final nextMembers =
        current.members.where((m) => m.userId != userId).toList();
    _userLobby.remove(userId);
    if (nextMembers.isEmpty) {
      _closeOpenIndex(current);
      _lobbies.remove(lobbyId);
      return current.copyWith(phase: 'cancelled', members: const []);
    }
    final next = current.copyWith(members: nextMembers);
    _lobbies[lobbyId] = next;
    return next;
  }

  LobbySnapshot markPromoted(String lobbyId, String matchId) {
    final current = _lobbies[lobbyId];
    if (current == null) {
      throw StateError('lobby not found: $lobbyId');
    }
    _closeOpenIndex(current);
    for (final m in current.members) {
      _userLobby.remove(m.userId);
    }
    final next = current.copyWith(phase: 'promoted', matchId: matchId);
    _lobbies[lobbyId] = next;
    return next;
  }

  void _closeOpenIndex(LobbySnapshot lobby) {
    final ids = _openByKey[lobby.queueKey];
    ids?.remove(lobby.lobbyId);
    if (ids != null && ids.isEmpty) {
      _openByKey.remove(lobby.queueKey);
    }
  }
}

final matchmakingStore = MatchmakingStore();
