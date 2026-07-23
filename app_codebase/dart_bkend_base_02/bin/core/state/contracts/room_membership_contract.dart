/// Room membership — subscribe / unsubscribe / list connections in a room.
library;

abstract interface class RoomMembershipContract {
  void subscribe(String roomId, String connectionId, {String? userId});

  void unsubscribe(String roomId, String connectionId);

  Set<String> connectionIds(String roomId);

  String? userIdFor(String connectionId);

  void onConnectionClosed(String connectionId);

  void clear();
}
