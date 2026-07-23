import '../../errors/api_error.dart';

/// Result of a login/register call — success value or structured API failure.
class AuthApiOutcome<T> {
  const AuthApiOutcome._({
    this.value,
    this.error,
    this.isNetworkError = false,
  });

  const AuthApiOutcome.success(T value) : this._(value: value);

  const AuthApiOutcome.failure({required ApiError error})
      : this._(error: error);

  const AuthApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? value;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => value != null;
}

/// FastAPI public auth endpoints — client-facing token issuer contract.
abstract interface class AuthApiContract {
  Future<AuthLoginResult?> devLogin(String userId);

  Future<AuthApiOutcome<AuthLoginResult>> register({
    required String username,
    required String email,
    required String password,
    bool isGuest = false,
  });

  Future<AuthApiOutcome<AuthLoginResult>> login({
    required String email,
    required String password,
  });

  Future<AuthRefreshResult?> refreshAccessToken(String refreshToken);

  /// Best-effort server revoke; local clear should still run if this fails.
  Future<void> logout(String refreshToken);

  Future<AuthApiOutcome<bool>> deleteAccount({
    required String accessToken,
    required String password,
    required String confirmation,
  });

  Future<AuthApiOutcome<AuthLoginResult>> convertGuestAccount({
    required String accessToken,
    required String guestEmail,
    required String username,
    required String email,
    required String password,
  });

  /// Public soft verify — no Bearer required.
  Future<AuthApiOutcome<bool>> verifyEmail({required String token});
}

class AuthLoginResult {
  const AuthLoginResult({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    this.isGuest = false,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final bool isGuest;
}

class AuthRefreshResult {
  const AuthRefreshResult({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    this.isGuest = false,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final bool isGuest;
}
