/// Disconnect cleanup for room membership.
library;

import '../state_registry.dart';

void onWsConnectionClosed(String connectionId) {
  roomRegistry.onConnectionClosed(connectionId);
}
