/// Bootstrap reset for tier-2 transport state.
library;

import 'connection_registry.dart';
import 'room/room_registry.dart';
import 'room/broadcast_hub.dart';

final connectionRegistry = ConnectionRegistry();
final roomRegistry = RoomRegistry();
final roomBroadcaster = BroadcastHub(
  connections: connectionRegistry,
  membership: roomRegistry,
);

void resetStateRegistry() {
  connectionRegistry.clear();
  roomRegistry.clear();
}
