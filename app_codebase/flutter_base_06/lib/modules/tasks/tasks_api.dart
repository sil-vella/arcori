import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import 'tasks_models.dart';

class TasksApiOutcome<T> {
  const TasksApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const TasksApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const TasksApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const TasksApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null && !isNetworkError;
}

class TasksApiClient {
  TasksApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<TasksApiOutcome<TasksCatalog>> fetchCatalog({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/daily_goals/catalog');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseCatalog(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const TasksApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  Future<TasksApiOutcome<TasksProgressSnapshot>> fetchProgress({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/daily_goals/progress');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseProgress(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const TasksApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  TasksApiOutcome<TasksCatalog> _parseCatalog(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return TasksApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return TasksApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return TasksApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return TasksApiOutcome.success(
      TasksCatalog.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  TasksApiOutcome<TasksProgressSnapshot> _parseProgress(
    http.Response response,
  ) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return TasksApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return TasksApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return TasksApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return TasksApiOutcome.success(
      TasksProgressSnapshot.fromJson(Map<String, dynamic>.from(data)),
    );
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
