import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../utils/dev_logger.dart';
import '../errors/api_error.dart';
import '../ws/ws_config.dart';
import 'contracts/auth_api_contract.dart';

export 'contracts/auth_api_contract.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// FastAPI public auth endpoints — single client-facing token issuer.
class AuthApiClient implements AuthApiContract {
  AuthApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<AuthLoginResult?> devLogin(String userId) async {
    final uri = Uri.parse('$_baseUrl/public/auth/dev-login');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    return _parseLoginResponse(response, fallbackUserId: userId);
  }

  @override
  Future<AuthApiOutcome<AuthLoginResult>> register({
    required String username,
    required String email,
    required String password,
    bool isGuest = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/public/auth/register');
    if (LOGGING_SWITCH && isGuest) {
      customlog(
        'AuthApiClient: guest register POST $uri username=$username email=$email',
      );
    }
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'is_guest': isGuest,
        }),
      );
      final outcome = _parseLoginOutcome(response);
      if (LOGGING_SWITCH && isGuest) {
        customlog(
          'AuthApiClient: guest register response status=${response.statusCode} '
          'ok=${outcome.isSuccess}',
        );
      }
      return outcome;
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AuthApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  @override
  Future<AuthApiOutcome<AuthLoginResult>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/public/auth/login');
    final isGuestEmail = email.endsWith('@arcori.arcori');
    if (LOGGING_SWITCH && isGuestEmail) {
      customlog('AuthApiClient: guest login fallback POST $uri email=$email');
    }
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final outcome = _parseLoginOutcome(response);
      if (LOGGING_SWITCH && isGuestEmail) {
        customlog(
          'AuthApiClient: guest login fallback response status=${response.statusCode} '
          'ok=${outcome.isSuccess}',
        );
      }
      return outcome;
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AuthApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  @override
  Future<AuthRefreshResult?> refreshAccessToken(String refreshToken) async {
    final uri = Uri.parse('$_baseUrl/public/auth/refresh');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] != true) return null;
    final data = body['data'] as Map<String, dynamic>;
    final access = data['access_token']?.toString();
    final refresh = data['refresh_token']?.toString();
    final userId = data['user_id']?.toString();
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return null;
    }
    return AuthRefreshResult(
      userId: userId,
      accessToken: access,
      refreshToken: refresh,
      isGuest: data['is_guest'] == true,
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    final uri = Uri.parse('$_baseUrl/public/auth/logout');
    try {
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    } on Exception {
      // Best-effort revoke; caller still clears local session.
    }
  }

  @override
  Future<AuthApiOutcome<bool>> deleteAccount({
    required String accessToken,
    required String password,
    required String confirmation,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/user/account/delete');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'password': password,
          'confirmation': confirmation,
        }),
      );
      return _parseOkOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AuthApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  @override
  Future<AuthApiOutcome<AuthLoginResult>> convertGuestAccount({
    required String accessToken,
    required String guestEmail,
    required String username,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/user/account/convert-guest');
    if (LOGGING_SWITCH) {
      customlog(
        'AuthApiClient: convertGuestAccount POST $uri '
        'guestEmail=$guestEmail username=$username email=$email',
      );
    }
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'guest_email': guestEmail,
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      final outcome = _parseLoginOutcome(response);
      if (LOGGING_SWITCH) {
        customlog(
          'AuthApiClient: convertGuestAccount response status=${response.statusCode} '
          'ok=${outcome.isSuccess} code=${outcome.error?.rawCode}',
        );
      }
      return outcome;
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AuthApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  @override
  Future<AuthApiOutcome<bool>> verifyEmail({required String token}) async {
    final uri = Uri.parse('$_baseUrl/public/auth/verify-email');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      return _parseOkOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AuthApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  AuthApiOutcome<bool> _parseOkOutcome(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return AuthApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (body['ok'] != true) {
      return AuthApiOutcome.failure(error: ApiError.fromEnvelope(body));
    }
    return const AuthApiOutcome.success(true);
  }

  AuthApiOutcome<AuthLoginResult> _parseLoginOutcome(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return AuthApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (body['ok'] != true) {
      return AuthApiOutcome.failure(error: ApiError.fromEnvelope(body));
    }
    final result = _loginResultFromData(body['data'] as Map<String, dynamic>);
    if (result == null) {
      return AuthApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid login response',
          rawCode: 'internal_error',
        ),
      );
    }
    return AuthApiOutcome.success(result);
  }

  Future<AuthLoginResult?> _parseLoginResponse(
    http.Response response, {
    String? fallbackUserId,
  }) async {
    final outcome = _parseLoginOutcome(response);
    if (outcome.isSuccess) {
      return outcome.value;
    }
    return null;
  }

  AuthLoginResult? _loginResultFromData(Map<String, dynamic> data) {
    final access = data['access_token']?.toString();
    final refresh = data['refresh_token']?.toString();
    final userId = data['user_id']?.toString();
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return null;
    }
    return AuthLoginResult(
      userId: userId,
      accessToken: access,
      refreshToken: refresh,
      isGuest: data['is_guest'] == true,
    );
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}
