/// Fan-out server push to all connections in a room.
library;

abstract interface class RoomBroadcasterContract {
  void broadcastToRoom(
    String roomId, {
    required String channel,
    required String type,
    required Map<String, dynamic> payload,
    String? excludeConnectionId,
  });
}
