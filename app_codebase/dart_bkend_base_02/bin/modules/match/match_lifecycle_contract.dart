/// Contract: matchmaking promotes lobbies into live matches (room SSOT).
library;

import 'match_models.dart';

class LobbyHumanSeat {
  const LobbyHumanSeat({
    required this.userId,
    required this.connectionId,
    this.arcoriIds = const [],
    this.slammerId = '',
  });

  final String userId;
  final String connectionId;
  final List<String> arcoriIds;
  final String slammerId;
}

abstract interface class MatchLifecycleContract {
  Future<MatchSnapshot> startFromLobby({
    required Map<String, dynamic> matchType,
    required List<LobbyHumanSeat> humans,
    required List<String> aiUserIds,
    int targetSeats = 3,
    String arenaId = stubArenaId,
  });
}
