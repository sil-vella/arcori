import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'auth_config.dart';
import 'auth_context.dart';

const _accessTyp = 'access';
const _refreshTyp = 'refresh';

class JwtTokenService {
  String issueAccess(String userId, {Map<String, dynamic>? extraClaims}) {
    return _issue(
      userId: userId,
      secret: jwtSecret(),
      tokenType: _accessTyp,
      expiresSeconds: jwtAccessExpiresSeconds(),
      extraClaims: extraClaims,
    );
  }

  String issueRefresh(String userId, {Map<String, dynamic>? extraClaims}) {
    return _issue(
      userId: userId,
      secret: jwtRefreshSecret(),
      tokenType: _refreshTyp,
      expiresSeconds: jwtRefreshExpiresSeconds(),
      extraClaims: extraClaims,
    );
  }

  AuthContext verifyAccess(String token) {
    return _verify(token, jwtSecret(), _accessTyp);
  }

  AuthContext verifyRefresh(String token) {
    return _verify(token, jwtRefreshSecret(), _refreshTyp);
  }

  String _issue({
    required String userId,
    required String secret,
    required String tokenType,
    required int expiresSeconds,
    Map<String, dynamic>? extraClaims,
  }) {
    if (secret.isEmpty) {
      throw StateError('JWT secret is not configured');
    }
    final payload = <String, dynamic>{
      'sub': userId,
      'typ': tokenType,
      if (extraClaims != null) ...extraClaims,
    };
    final jwt = JWT(payload);
    return jwt.sign(
      SecretKey(secret),
      expiresIn: Duration(seconds: expiresSeconds),
    );
  }

  AuthContext _verify(String token, String secret, String expectedType) {
    if (secret.isEmpty) {
      throw JWTException('JWT secret is not configured');
    }
    final jwt = JWT.verify(token, SecretKey(secret));
    final payload = jwt.payload;
    if (payload is! Map<String, dynamic>) {
      throw JWTException('invalid payload');
    }
    if (payload['typ'] != expectedType) {
      throw JWTException('wrong token type');
    }
    final userId = payload['sub']?.toString();
    if (userId == null || userId.isEmpty) {
      throw JWTException('missing subject');
    }
    return AuthContext(userId: userId, claims: payload);
  }
}

final tokenService = JwtTokenService();
