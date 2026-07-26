import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import 'avari_models.dart';

class AvariApiOutcome<T> {
  const AvariApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const AvariApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const AvariApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const AvariApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null && !isNetworkError;
}

class AvariApiClient {
  AvariApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<AvariApiOutcome<AvariProfile>> fetchProfile({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/avari/profile');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseProfile(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  AvariApiOutcome<AvariProfile> _parseProfile(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return AvariApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return AvariApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return AvariApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return AvariApiOutcome.success(
      AvariProfile.fromJson(Map<String, dynamic>.from(data)),
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
