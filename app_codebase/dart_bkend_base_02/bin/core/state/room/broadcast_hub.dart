/// Tier 2 — broadcast server push to room members via [ConnectionRegistry].
library;

import '../../ws/response/ws_response.dart';
import '../connection_registry.dart';
import '../contracts/room_broadcaster_contract.dart';
import '../contracts/room_membership_contract.dart';

class BroadcastHub implements RoomBroadcasterContract {
  BroadcastHub({
    required ConnectionRegistry connections,
    required RoomMembershipContract membership,
  })  : _connections = connections,
        _membership = membership;

  final ConnectionRegistry _connections;
  final RoomMembershipContract _membership;

  @override
  void broadcastToRoom(
    String roomId, {
    required String channel,
    required String type,
    required Map<String, dynamic> payload,
    String? excludeConnectionId,
  }) {
    final frame = encodeWsOk({
      'type': type,
      'channel': channel,
      'payload': payload,
    });
    for (final connectionId in _membership.connectionIds(roomId)) {
      if (connectionId == excludeConnectionId) continue;
      _connections.send(connectionId, frame);
    }
  }
}
