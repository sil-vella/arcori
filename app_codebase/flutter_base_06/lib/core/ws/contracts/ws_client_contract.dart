/// WebSocket client contract for testability.
abstract interface class WsClientContract {
  Stream<Map<String, dynamic>> get messages;

  /// Fires when the socket closes unexpectedly (not after [disconnect]).
  Stream<void> get connectionClosed;

  bool get isConnected;

  Future<void> connect({
    required String url,
    String? accessToken,
    String? serviceKey,
  });

  Future<void> send({
    required String type,
    required String channel,
    Map<String, dynamic>? payload,
  });

  Future<void> disconnect();
}
