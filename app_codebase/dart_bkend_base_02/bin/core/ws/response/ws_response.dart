/// Encode/decode WebSocket JSON frames using the HTTP JSON envelope.
library;

import 'dart:convert';

import '../../http/response/response.dart';

String encodeWsOk(Object? data) => jsonEncode(jsonSuccessBody(data));

String encodeWsError({required String code, required String message}) =>
    jsonEncode(jsonErrorBody(code: code, message: message));

({Map<String, dynamic>? data, Map<String, String>? error}) parseIncoming(
  String text,
) {
  try {
    final raw = jsonDecode(text);
    if (raw is! Map) {
      return (
        data: null,
        error: {'code': 'invalid_json', 'message': 'Message must be a JSON object'},
      );
    }
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] == true && map['data'] is Map) {
      return (data: Map<String, dynamic>.from(map['data'] as Map), error: null);
    }
    if (map['ok'] == false && map['error'] is Map) {
      final err = Map<String, dynamic>.from(map['error'] as Map);
      return (
        data: null,
        error: {
          'code': err['code']?.toString() ?? 'invalid_message',
          'message': err['message']?.toString() ?? 'Invalid message',
        },
      );
    }
    if (map.containsKey('type') && map.containsKey('channel')) {
      return (data: map, error: null);
    }
    return (
      data: null,
      error: {
        'code': 'invalid_message',
        'message': 'Expected {type, channel} in data',
      },
    );
  } catch (_) {
    return (
      data: null,
      error: {'code': 'invalid_json', 'message': 'Message must be valid JSON'},
    );
  }
}
