/// Shared access JWT verification for HTTP guards and WS auth handshake.
library;

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../errors/app_error.dart';
import '../errors/error_codes.dart';
import 'auth_context.dart';
import 'jwt_token_service.dart';

AuthContext _verifyAccessToken(String token) {
  try {
    return tokenService.verifyAccess(token.trim());
  } on JWTExpiredException {
    throw AppError(tokenExpired);
  } on JWTException {
    throw AppError(invalidToken);
  }
}

AuthContext verifyBearerOrThrow(String? token) {
  if (token == null || token.trim().isEmpty) {
    throw AppError(unauthorized, message: 'Bearer token required');
  }
  return _verifyAccessToken(token);
}

AuthContext verifyAccessOrThrow(String? token) {
  if (token == null || token.trim().isEmpty) {
    throw AppError(unauthorized, message: 'access_token required');
  }
  return _verifyAccessToken(token);
}
