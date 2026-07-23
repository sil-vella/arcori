/// Drain mode service — set flag and readiness snapshot.
library;

import '../../core/state/state_registry.dart';
import 'ops_state.dart';

void setDrainMode(bool enabled) {
  setDrainModeFlag(enabled);
}

Map<String, dynamic> drainStatus() {
  final rooms = roomRegistry.roomCount;
  return {
    'drain_mode': drainMode,
    'active_rooms': rooms,
    'room_count': rooms,
    'dart_connections': connectionRegistry.connectionCount,
  };
}
