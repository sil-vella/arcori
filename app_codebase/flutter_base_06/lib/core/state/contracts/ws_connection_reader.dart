/// Read-only WebSocket connection status for UI and modules.
abstract interface class WsConnectionReader {
  bool isConnected(String connectionId);

  /// Latest known status per logical connection (`dart`, `api`, …).
  Map<String, bool> get connectionStatus;
}
