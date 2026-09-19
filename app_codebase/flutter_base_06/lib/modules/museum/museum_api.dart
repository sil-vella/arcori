import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import '../../utils/dev_logger.dart';
import 'museum_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class MuseumApiOutcome<T> {
  const MuseumApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const MuseumApiOutcome.success(T data) : this._(data: data);

  const MuseumApiOutcome.failure({ApiError? error, bool isNetworkError = false})
      : this._(error: error, isNetworkError: isNetworkError);

  const MuseumApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null && !isNetworkError;
}

class MuseumApiClient {
  MuseumApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<MuseumApiOutcome<MuseumListPage>> fetchList({
    required String accessToken,
    String outcome = 'all',
    String? q,
    int limit = 30,
    String? cursor,
  }) async {
    final params = <String, String>{
      'outcome': outcome,
      'limit': '$limit',
    };
    final query = (q ?? '').trim();
    if (query.isNotEmpty) params['q'] = query;
    final cur = (cursor ?? '').trim();
    if (cur.isNotEmpty) params['cursor'] = cur;

    final uri = Uri.parse('$_baseUrl/authuser/museum').replace(
      queryParameters: params,
    );
    try {
      if (LOGGING_SWITCH) {
        customlog('MuseumApi: GET museum outcome=$outcome q=$query');
      }
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseList(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const MuseumApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  Future<MuseumApiOutcome<MuseumItem>> fetchItem({
    required String accessToken,
    required String designId,
    required int generationNumber,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/museum/item').replace(
      queryParameters: {
        'designId': designId,
        'generationNumber': '$generationNumber',
      },
    );
    try {
      if (LOGGING_SWITCH) {
        customlog(
          'MuseumApi: GET museum/item design=$designId gen=$generationNumber',
        );
      }
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseItem(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const MuseumApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  MuseumApiOutcome<MuseumListPage> _parseList(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return MuseumApiOutcome.failure(error: _invalidResponse());
    }
    if (envelope['ok'] != true) {
      return MuseumApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return MuseumApiOutcome.failure(error: _invalidResponse());
    }
    return MuseumApiOutcome.success(
      MuseumListPage.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  MuseumApiOutcome<MuseumItem> _parseItem(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return MuseumApiOutcome.failure(error: _invalidResponse());
    }
    if (envelope['ok'] != true) {
      return MuseumApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return MuseumApiOutcome.failure(error: _invalidResponse());
    }
    return MuseumApiOutcome.success(
      MuseumItem.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  ApiError _invalidResponse() => ApiError(
        code: CoreApiErrorCode.internalError,
        message: 'Invalid server response',
        rawCode: 'internal_error',
      );

  Map<String, dynamic>? _decodeEnvelope(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _isNetworkError(Object e) =>
      e is SocketException ||
      e is http.ClientException ||
      e is TimeoutException;
}
