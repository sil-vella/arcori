/// Read-only auth session contract for cross-module access.
abstract interface class AuthSessionReader {
  bool get isAuthenticated;

  String? get accessToken;

  String? get userId;
}
