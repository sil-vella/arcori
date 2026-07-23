/// WebSocket message shapes — shared wire format matching HTTP JSON envelope.
library;

class WsConnectionContext {
  WsConnectionContext({
    required this.tier,
    required this.connectionId,
    this.userId,
    this.claims = const {},
    this.authenticated = false,
  });

  final String tier;
  final String connectionId;
  String? userId;
  Map<String, dynamic> claims;
  bool authenticated;
}

class WsClientMessage {
  WsClientMessage({
    required this.msgType,
    required this.channel,
    this.payload = const {},
  });

  final String msgType;
  final String channel;
  final Map<String, dynamic> payload;

  static WsClientMessage? fromData(Map<String, dynamic> data) {
    final msgType = data['type']?.toString().trim() ?? '';
    final channel = data['channel']?.toString().trim() ?? '';
    if (msgType.isEmpty || channel.isEmpty) return null;
    final rawPayload = data['payload'];
    final payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : <String, dynamic>{};
    return WsClientMessage(
      msgType: msgType,
      channel: channel,
      payload: payload,
    );
  }
}

/// Handler returns response data map, error map with `_wsSendError`, or null.
typedef WsChannelHandler = Map<String, dynamic>? Function(
  WsConnectionContext ctx,
  WsClientMessage msg,
);
