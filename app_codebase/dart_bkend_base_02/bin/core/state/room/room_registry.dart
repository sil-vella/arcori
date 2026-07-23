/// Tier 2 — room membership (connectionId ↔ roomId).
library;

import '../contracts/room_membership_contract.dart';

class RoomRegistry implements RoomMembershipContract {
  final Map<String, Set<String>> _roomConnections = {};
  final Map<String, Set<String>> _connectionRooms = {};
  final Map<String, String?> _connectionUsers = {};

  @override
  void subscribe(String roomId, String connectionId, {String? userId}) {
    _roomConnections.putIfAbsent(roomId, () => {}).add(connectionId);
    _connectionRooms.putIfAbsent(connectionId, () => {}).add(roomId);
    _connectionUsers[connectionId] = userId;
  }

  @override
  void unsubscribe(String roomId, String connectionId) {
    _roomConnections[roomId]?.remove(connectionId);
    if (_roomConnections[roomId]?.isEmpty ?? false) {
      _roomConnections.remove(roomId);
    }
    _connectionRooms[connectionId]?.remove(roomId);
    if (_connectionRooms[connectionId]?.isEmpty ?? false) {
      _connectionRooms.remove(connectionId);
      _connectionUsers.remove(connectionId);
    }
  }

  @override
  Set<String> connectionIds(String roomId) =>
      Set<String>.from(_roomConnections[roomId] ?? const {});

  /// Number of rooms with at least one connection (active rooms for drain).
  int get roomCount => _roomConnections.length;

  @override
  String? userIdFor(String connectionId) => _connectionUsers[connectionId];

  @override
  void onConnectionClosed(String connectionId) {
    final rooms = _connectionRooms.remove(connectionId);
    _connectionUsers.remove(connectionId);
    if (rooms == null) return;
    for (final roomId in rooms) {
      _roomConnections[roomId]?.remove(connectionId);
      if (_roomConnections[roomId]?.isEmpty ?? false) {
        _roomConnections.remove(roomId);
      }
    }
  }

  @override
  void clear() {
    _roomConnections.clear();
    _connectionRooms.clear();
    _connectionUsers.clear();
  }
}
