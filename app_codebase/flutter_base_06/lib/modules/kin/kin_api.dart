import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import '../avari/avari_api.dart';
import '../avari/avari_models.dart';

/// POST /authuser/avari/kin — claim Genesis Kin Arcori.
class KinApiClient {
  KinApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<AvariApiOutcome<AvariKin>> claimKin({
    required String accessToken,
    required String kinSerial,
    required String typeSerial,
    required String chosenName,
    required String regionCode,
    required String color,
    required List<Map<String, dynamic>> applied,
    Map<String, dynamic>? background,
    Map<String, dynamic>? lottie,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/avari/kin');
    final body = <String, dynamic>{
      'kinSerial': kinSerial,
      'typeSerial': typeSerial,
      'chosenName': chosenName,
      'regionCode': regionCode,
      'color': color,
      'applied': applied,
      if (background != null) 'background': background,
      if (lottie != null) 'lottie': lottie,
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
      return _parseClaim(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  AvariApiOutcome<AvariKin> _parseClaim(http.Response response) {
    Map<String, dynamic>? envelope;
    try {
      envelope = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      envelope = null;
    }
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
    final kinRaw = data['kin'];
    if (kinRaw is! Map) {
      return AvariApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid Kin payload',
          rawCode: 'internal_error',
        ),
      );
    }
    return AvariApiOutcome.success(
      AvariKin.fromJson(Map<String, dynamic>.from(kinRaw)),
    );
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}
