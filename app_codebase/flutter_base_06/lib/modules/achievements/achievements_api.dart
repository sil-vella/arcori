import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import 'achievements_models.dart';

class AchievementsApiOutcome<T> {
  const AchievementsApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const AchievementsApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const AchievementsApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const AchievementsApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null && !isNetworkError;
}

class AchievementsApiClient {
  AchievementsApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<AchievementsApiOutcome<AchievementsCatalog>> fetchCatalog({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/achievements/catalog');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseCatalog(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AchievementsApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  Future<AchievementsApiOutcome<List<String>>> fetchUnlockedIds({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/achievements/unlocked');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseUnlocked(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AchievementsApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  AchievementsApiOutcome<AchievementsCatalog> _parseCatalog(
    http.Response response,
  ) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return AchievementsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return AchievementsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return AchievementsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return AchievementsApiOutcome.success(
      AchievementsCatalog.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  AchievementsApiOutcome<List<String>> _parseUnlocked(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return AchievementsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return AchievementsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return AchievementsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    final idsRaw = data['ids'];
    final ids = idsRaw is List
        ? idsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return AchievementsApiOutcome.success(ids);
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
