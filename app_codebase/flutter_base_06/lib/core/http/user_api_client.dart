import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../errors/api_error.dart';
import '../ws/ws_config.dart';
import 'contracts/user_api_contract.dart';

export 'contracts/user_api_contract.dart';

/// Authenticated user profile endpoints.
class UserApiClient implements UserApiContract {
  UserApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  static const int avatarMaxUploadBytes = 2 * 1024 * 1024;

  @override
  Future<UserApiOutcome<UserProfile>> fetchProfile({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/user/profile');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseProfileOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const UserApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  @override
  Future<UserApiOutcome<AvatarUploadResult>> uploadAvatar({
    required String accessToken,
    required List<int> bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) {
      return UserApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.invalidMessage,
          message: 'Avatar file is required',
          rawCode: 'invalid_request',
        ),
      );
    }
    if (bytes.length > avatarMaxUploadBytes) {
      return UserApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.invalidMessage,
          message: 'Avatar file exceeds maximum size (2 MB)',
          rawCode: 'invalid_request',
        ),
      );
    }

    final uri = Uri.parse('$_baseUrl/authuser/user/profile/avatar');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: filename,
          contentType: _mediaTypeForFilename(filename),
        ),
      );

    try {
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      return _parseAvatarUploadOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const UserApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  @override
  Future<UserApiOutcome<UserProfile>> deleteAvatar({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/user/profile/avatar');
    try {
      final response = await _client.delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseProfileEnvelopeOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const UserApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  @override
  Future<UserApiOutcome<bool>> resendEmailVerification({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/user/account/resend-verification');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: '{}',
      );
      final envelope = _decodeEnvelope(response.body);
      if (envelope == null) {
        return UserApiOutcome.failure(
          error: ApiError(
            code: CoreApiErrorCode.internalError,
            message: 'Invalid server response',
            rawCode: 'internal_error',
          ),
        );
      }
      if (envelope['ok'] != true) {
        return UserApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
      }
      return const UserApiOutcome.success(true);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const UserApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  UserApiOutcome<UserProfile> _parseProfileOutcome(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return UserApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return UserApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'] as Map<String, dynamic>;
    final profileJson = data['profile'] as Map<String, dynamic>? ?? data;
    return UserApiOutcome.success(UserProfile.fromJson(profileJson));
  }

  UserApiOutcome<UserProfile> _parseProfileEnvelopeOutcome(
    http.Response response,
  ) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return UserApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return UserApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'] as Map<String, dynamic>;
    final profileJson = data['profile'] as Map<String, dynamic>? ?? const {};
    return UserApiOutcome.success(UserProfile.fromJson(profileJson));
  }

  UserApiOutcome<AvatarUploadResult> _parseAvatarUploadOutcome(
    http.Response response,
  ) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return UserApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return UserApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'] as Map<String, dynamic>;
    return UserApiOutcome.success(AvatarUploadResult.fromJson(data));
  }

  Map<String, dynamic>? _decodeEnvelope(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  MediaType? _mediaTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}
