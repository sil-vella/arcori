import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';

class FriendMatchInviteApiOutcome<T> {
  const FriendMatchInviteApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const FriendMatchInviteApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const FriendMatchInviteApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const FriendMatchInviteApiOutcome.networkFailure()
      : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null;
}

class FriendMatchInviteApiClient {
  FriendMatchInviteApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<FriendMatchInviteApiOutcome<String>> createInvite({
    required String accessToken,
    required String invitedUserId,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/friend_match_invites/create');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'invited_user_id': invitedUserId,
        }),
      );
      return _parseOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const FriendMatchInviteApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  FriendMatchInviteApiOutcome<String> _parseOutcome(http.Response response) {
    Map<String, dynamic>? envelope;
    try {
      envelope = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      envelope = null;
    }
    if (envelope == null) {
      return FriendMatchInviteApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return FriendMatchInviteApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }

    final data = envelope['data'];
    if (data is! Map) {
      return FriendMatchInviteApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    final inviteId = data['inviteId']?.toString() ?? '';
    if (inviteId.isEmpty) {
      return FriendMatchInviteApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'inviteId missing in server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return FriendMatchInviteApiOutcome.success(inviteId);
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}

