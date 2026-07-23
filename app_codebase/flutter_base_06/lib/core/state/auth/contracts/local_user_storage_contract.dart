/// Locally persisted user credentials for re-login after token expiry.
class StoredLocalUser {
  const StoredLocalUser({
    required this.username,
    required this.email,
    required this.password,
    required this.isGuest,
  });

  final String username;
  final String email;
  final String password;
  final bool isGuest;
}

/// Read/write local user profile — swap impl for tests.
abstract interface class LocalUserStorageContract {
  Future<StoredLocalUser?> read();

  Future<void> write(StoredLocalUser user);

  Future<void> clear();
}
