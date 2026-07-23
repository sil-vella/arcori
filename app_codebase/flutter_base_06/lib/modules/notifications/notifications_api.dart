import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import 'notifications_state.dart';

class NotificationsApiOutcome<T> {
  const NotificationsApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const NotificationsApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const NotificationsApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const NotificationsApiOutcome.networkFailure()
      : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null;
}

class NotificationsListResult {
  const NotificationsListResult({
    required this.messages,
    required this.unreadCount,
  });

  final List<NotificationMessage> messages;
  final int unreadCount;
}

class NotificationsApiClient {
  NotificationsApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<NotificationsApiOutcome<NotificationsListResult>> fetchMessages({
    required String accessToken,
    bool unreadOnly = false,
    int limit = 50,
    int offset = 0,
  }) {
    final uri = Uri.parse('$_baseUrl/authuser/notifications/messages').replace(
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
        'unread_only': unreadOnly ? 'true' : 'false',
      },
    );
    return _getList(uri, accessToken: accessToken);
  }

  Future<NotificationsApiOutcome<NotificationsListResult>> fetchGlobals({
    required String accessToken,
  }) {
    final uri = Uri.parse('$_baseUrl/authuser/notifications/globals');
    return _getList(uri, accessToken: accessToken);
  }

  Future<NotificationsApiOutcome<void>> markRead({
    required String accessToken,
    required List<String> messageIds,
  }) {
    return _post(
      Uri.parse('$_baseUrl/authuser/notifications/mark-read'),
      accessToken: accessToken,
      body: {'message_ids': messageIds},
    );
  }

  Future<NotificationsApiOutcome<void>> markGlobalRead({
    required String accessToken,
    required List<String> globalMessageIds,
  }) {
    return _post(
      Uri.parse('$_baseUrl/authuser/notifications/global-mark-read'),
      accessToken: accessToken,
      body: {'global_message_ids': globalMessageIds},
    );
  }

  Future<NotificationsApiOutcome<void>> deleteMessages({
    required String accessToken,
    required List<String> messageIds,
  }) {
    return _post(
      Uri.parse('$_baseUrl/authuser/notifications/delete'),
      accessToken: accessToken,
      body: {'message_ids': messageIds},
    );
  }

  Future<NotificationsApiOutcome<Map<String, dynamic>?>> submitResponse({
    required String accessToken,
    String? messageId,
    String? globalMessageId,
    required String optionKey,
  }) {
    final body = <String, dynamic>{'option_key': optionKey};
    if (messageId != null && messageId.isNotEmpty) {
      body['message_id'] = messageId;
    }
    if (globalMessageId != null && globalMessageId.isNotEmpty) {
      body['global_message_id'] = globalMessageId;
    }
    return _postResponse(
      Uri.parse('$_baseUrl/authuser/notifications/response'),
      accessToken: accessToken,
      body: body,
    );
  }

  Future<NotificationsApiOutcome<NotificationsListResult>> _getList(
    Uri uri, {
    required String accessToken,
  }) async {
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseListOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const NotificationsApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  Future<NotificationsApiOutcome<void>> _post(
    Uri uri, {
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return _parseVoidOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const NotificationsApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  Future<NotificationsApiOutcome<Map<String, dynamic>?>> _postResponse(
    Uri uri, {
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return _parseResponseOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const NotificationsApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  NotificationsApiOutcome<NotificationsListResult> _parseListOutcome(
    http.Response response,
  ) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return NotificationsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return NotificationsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'] as Map<String, dynamic>? ?? const {};
    final rawMessages = data['messages'];
    final messages = rawMessages is List
        ? rawMessages
            .whereType<Map>()
            .map((item) => NotificationMessage.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList()
        : <NotificationMessage>[];
    final unreadCount = data['unread_count'] is int
        ? data['unread_count'] as int
        : int.tryParse('${data['unread_count']}') ?? 0;
    return NotificationsApiOutcome.success(
      NotificationsListResult(messages: messages, unreadCount: unreadCount),
    );
  }

  NotificationsApiOutcome<void> _parseVoidOutcome(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return NotificationsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return NotificationsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    return const NotificationsApiOutcome.success(null);
  }

  NotificationsApiOutcome<Map<String, dynamic>?> _parseResponseOutcome(
    http.Response response,
  ) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return NotificationsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return NotificationsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is Map) {
      return NotificationsApiOutcome.success(Map<String, dynamic>.from(data));
    }
    return const NotificationsApiOutcome.success(null);
  }

  Map<String, dynamic>? _decodeEnvelope(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}
