/// In-process drain flag for the Dart realtime server.
library;

bool _drainMode = false;

bool get drainMode => _drainMode;

void setDrainModeFlag(bool enabled) {
  _drainMode = enabled;
}

void resetOpsState() {
  _drainMode = false;
}
