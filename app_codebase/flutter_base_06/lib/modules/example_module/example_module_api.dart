import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';

class ExampleModuleApiOutcome<T> {
  const ExampleModuleApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const ExampleModuleApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const ExampleModuleApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const ExampleModuleApiOutcome.networkFailure()
      : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null;
}

class ExampleDemoNotificationsResult {
  const ExampleDemoNotificationsResult({
    required this.navigateMessageId,
    required this.replyMessageId,
  });

  final String navigateMessageId;
  final String replyMessageId;

  factory ExampleDemoNotificationsResult.fromJson(Map<String, dynamic> json) {
    return ExampleDemoNotificationsResult(
      navigateMessageId: json['navigate_message_id']?.toString() ?? '',
      replyMessageId: json['reply_message_id']?.toString() ?? '',
    );
  }
}

class ExampleModuleApiClient {
  ExampleModuleApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<ExampleModuleApiOutcome<ExampleDemoNotificationsResult>>
      sendDemoNotifications({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/example_module/demo-notifications');
    try {
      final response = await _client.post(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const ExampleModuleApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  ExampleModuleApiOutcome<ExampleDemoNotificationsResult> _parseOutcome(
    http.Response response,
  ) {
    Map<String, dynamic>? envelope;
    try {
      envelope = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      envelope = null;
    }
    if (envelope == null) {
      return ExampleModuleApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return ExampleModuleApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return ExampleModuleApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return ExampleModuleApiOutcome.success(
      ExampleDemoNotificationsResult.fromJson(
        Map<String, dynamic>.from(data),
      ),
    );
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}
