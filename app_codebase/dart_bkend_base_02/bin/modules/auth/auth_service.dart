import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

import '../../core/auth/auth_config.dart';
import '../../core/auth/jwt_token_service.dart';

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final body = await request.readAsString();
  if (body.isEmpty) return {};
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  return {};
}

Map<String, dynamic>? devLogin(String userId) {
  if (!devLoginAllowed()) return null;
  final trimmed = userId.trim();
  if (trimmed.isEmpty) return null;
  return {
    'user_id': trimmed,
    'access_token': tokenService.issueAccess(trimmed),
    'refresh_token': tokenService.issueRefresh(trimmed),
    'token_type': 'Bearer',
  };
}

Map<String, dynamic>? refreshAccessToken(String refreshToken) {
  final trimmed = refreshToken.trim();
  if (trimmed.isEmpty) return null;
  try {
    final ctx = tokenService.verifyRefresh(trimmed);
    return {
      'user_id': ctx.userId,
      'access_token': tokenService.issueAccess(ctx.userId),
      'token_type': 'Bearer',
    };
  } on JWTException {
    return null;
  }
}

Map<String, dynamic>? validateAccessToken(String accessToken) {
  final trimmed = accessToken.trim();
  if (trimmed.isEmpty) return null;
  try {
    final ctx = tokenService.verifyAccess(trimmed);
    return {
      'user_id': ctx.userId,
      'claims': ctx.claims,
      'valid': true,
    };
  } on JWTException {
    return null;
  }
}
