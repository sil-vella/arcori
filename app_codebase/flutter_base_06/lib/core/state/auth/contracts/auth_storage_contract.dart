/// Persisted session fields for bootstrap.
class StoredAuthSession {
  const StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
}

/// Read/write auth tokens — swap impl for tests or web.
abstract interface class AuthStorageContract {
  Future<StoredAuthSession?> read();

  Future<void> write({
    required String accessToken,
    required String refreshToken,
    required String userId,
  });

  Future<void> clear();
}
