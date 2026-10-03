import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import '../avari/avari_api.dart';
import '../avari/avari_models.dart';

/// POST /authuser/avari/kin — claim Genesis Kin Arcori.
///
/// Human claim: multipart `payload` (metadata JSON) + `lottie.gz` (client-baked
/// preview Lottie). Server WebP-optimizes only — client is SSOT for layout.
/// AI / tools may omit Lottie so the server bakes from catalog + applied.
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
    /// Client-baked Lottie JSON (preview SSOT). Gzipped for multipart upload.
    String? lottieJson,
    /// Optional gzipped Lottie bytes via multipart (tools).
    List<int>? lottieGzipBytes,
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
    };
    List<int>? gzipLottie = lottieGzipBytes;
    if ((gzipLottie == null || gzipLottie.isEmpty) &&
        lottieJson != null &&
        lottieJson.isNotEmpty) {
      gzipLottie = gzip.encode(utf8.encode(lottieJson));
    }
    try {
      final http.Response response;
      if (gzipLottie != null && gzipLottie.isNotEmpty) {
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $accessToken';
        request.files.add(
          http.MultipartFile.fromString(
            'payload',
            jsonEncode(body),
            filename: 'payload.json',
            contentType: MediaType('application', 'json'),
          ),
        );
        request.files.add(
          http.MultipartFile.fromBytes(
            'lottie.gz',
            gzipLottie,
            filename: 'lottie.json.gz',
            contentType: MediaType('application', 'gzip'),
          ),
        );
        final streamed = await _client.send(request);
        response = await http.Response.fromStream(streamed);
      } else {
        final jsonBytes = utf8.encode(jsonEncode(body));
        final gzipped = gzip.encode(jsonBytes);
        response = await _client.post(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Content-Encoding': 'gzip',
          },
          body: gzipped,
        );
      }
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
      final code = response.statusCode;
      if (code == 413) {
        return AvariApiOutcome.failure(
          error: ApiError(
            code: CoreApiErrorCode.internalError,
            message: 'Claim too large for server — try again after update',
            rawCode: 'payload_too_large',
          ),
        );
      }
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
