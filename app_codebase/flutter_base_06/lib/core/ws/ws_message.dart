import 'dart:convert';

/// Parse and build WebSocket JSON envelopes (matches HTTP `{ok, data}` / `{ok, error}`).
class WsMessage {
  const WsMessage._({
    required this.ok,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  final bool ok;
  final Map<String, dynamic>? data;
  final String? errorCode;
  final String? errorMessage;

  static WsMessage parse(String text) {
    final raw = jsonDecode(text);
    if (raw is! Map) {
      return const WsMessage._(
        ok: false,
        errorCode: 'invalid_json',
        errorMessage: 'Expected JSON object',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] == true) {
      final data = map['data'];
      return WsMessage._(
        ok: true,
        data: data is Map ? Map<String, dynamic>.from(data) : null,
      );
    }
    if (map['ok'] == false && map['error'] is Map) {
      final err = Map<String, dynamic>.from(map['error'] as Map);
      return WsMessage._(
        ok: false,
        errorCode: err['code']?.toString(),
        errorMessage: err['message']?.toString(),
      );
    }
    return const WsMessage._(
      ok: false,
      errorCode: 'invalid_message',
      errorMessage: 'Unknown envelope',
    );
  }

  static String encodeClient({
    required String type,
    required String channel,
    Map<String, dynamic>? payload,
  }) {
    return jsonEncode({
      'type': type,
      'channel': channel,
      if (payload != null) 'payload': payload,
    });
  }
}
