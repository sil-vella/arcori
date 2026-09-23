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

  /// GET /authuser/avari/mastery/recent — Home mastery ticker.
  Future<AvariApiOutcome<List<MasteryRecentChange>>> fetchMasteryRecent({
    required String accessToken,
    int limit = 5,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/avari/mastery/recent')
        .replace(queryParameters: {'limit': '$limit'});
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseMasteryRecent(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  /// POST /authuser/avari/match/finalize — flip fragments + mastery (fee pre-paid).
  Future<AvariApiOutcome<MatchFinalizeResult>> finalizeMatch({
    required String accessToken,
    required String matchId,
    required String matchType,
    required bool practice,
    required List<String> designIds,
    int flips = 0,
    String? playedDesignId,
    String? eventId,
    Map<String, int>? flipsByDesign,
    Map<String, dynamic>? result,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/avari/match/finalize');
    final body = <String, dynamic>{
      'matchId': matchId,
      'matchType': matchType,
      'practice': practice,
      'designIds': designIds,
      'flips': flips,
      if (playedDesignId != null && playedDesignId.trim().isNotEmpty)
        'playedDesignId': playedDesignId.trim(),
      if (eventId != null && eventId.trim().isNotEmpty)
        'eventId': eventId.trim(),
      if (flipsByDesign != null && flipsByDesign.isNotEmpty)
        'flipsByDesign': flipsByDesign,
      if (result != null) 'result': result,
    };
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return _parseFinalize(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  /// POST /authuser/avari/match/pay_fee — deduct before matchmaking.
  Future<AvariApiOutcome<MatchFeeResult>> payMatchFee({
    required String accessToken,
    required String matchType,
    required String feeIntentId,
    String? eventId,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/avari/match/pay_fee');
    try {
      final body = <String, dynamic>{
        'matchType': matchType,
        'feeIntentId': feeIntentId,
      };
      final eid = eventId?.trim() ?? '';
      if (eid.isNotEmpty) body['eventId'] = eid;
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return _parseFee(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  /// POST /authuser/avari/match/refund_fee — restore fee if queue never started.
  Future<AvariApiOutcome<MatchFeeResult>> refundMatchFee({
    required String accessToken,
    required String matchType,
    required String feeIntentId,
    int? feeFragments,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/avari/match/refund_fee');
    final body = <String, dynamic>{
      'matchType': matchType,
      'feeIntentId': feeIntentId,
      if (feeFragments != null) 'feeFragments': feeFragments,
    };
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return _parseFee(response);
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

  AvariApiOutcome<List<MasteryRecentChange>> _parseMasteryRecent(
    http.Response response,
  ) {
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
    final raw = data['items'];
    final items = <MasteryRecentChange>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) {
          items.add(
            MasteryRecentChange.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
    }
    return AvariApiOutcome.success(items);
  }

  AvariApiOutcome<MatchFinalizeResult> _parseFinalize(http.Response response) {
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
      MatchFinalizeResult.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  AvariApiOutcome<MatchFeeResult> _parseFee(http.Response response) {
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
      MatchFeeResult.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  /// POST /authuser/avari/spend_slammer_charge — practice slam charge spend.
  Future<AvariApiOutcome<Map<String, dynamic>>> spendSlammerCharge({
    required String accessToken,
    required String designId,
    String? matchId,
    String? intentId,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/avari/spend_slammer_charge');
    final body = <String, dynamic>{
      'designId': designId.trim(),
      if (matchId != null && matchId.trim().isNotEmpty) 'matchId': matchId.trim(),
      if (intentId != null && intentId.trim().isNotEmpty)
        'intentId': intentId.trim(),
    };
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
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
      return AvariApiOutcome.success(Map<String, dynamic>.from(data));
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
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
