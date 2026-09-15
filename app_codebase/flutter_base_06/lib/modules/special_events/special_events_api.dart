import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import 'special_events_models.dart';

class SpecialEventsApiOutcome<T> {
  const SpecialEventsApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const SpecialEventsApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const SpecialEventsApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const SpecialEventsApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null && !isNetworkError;
}

class SpecialEventsApiClient {
  SpecialEventsApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<SpecialEventsApiOutcome<SpecialEventsCatalog>> fetchCatalog({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/special_events/catalog');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseCatalog(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const SpecialEventsApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  SpecialEventsApiOutcome<SpecialEventsCatalog> _parseCatalog(
    http.Response response,
  ) {
    Map<String, dynamic>? envelope;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) envelope = Map<String, dynamic>.from(decoded);
    } catch (_) {
      envelope = null;
    }
    if (envelope == null) {
      return SpecialEventsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return SpecialEventsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return SpecialEventsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return SpecialEventsApiOutcome.success(
      SpecialEventsCatalog.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  bool _isNetworkError(Object e) =>
      e is SocketException ||
      e is http.ClientException ||
      e is TimeoutException;
}
