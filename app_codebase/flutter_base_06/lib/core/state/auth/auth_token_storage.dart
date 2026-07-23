import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'contracts/auth_storage_contract.dart';

/// Secure token storage (mobile/desktop; web uses platform defaults).
class AuthTokenStorage implements AuthStorageContract {
  AuthTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _accessKey = 'arcori_access_token';
  static const _refreshKey = 'arcori_refresh_token';
  static const _userIdKey = 'arcori_user_id';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredAuthSession?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    final userId = await _storage.read(key: _userIdKey);
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return null;
    }
    return StoredAuthSession(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
    );
  }

  @override
  Future<void> write({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userIdKey);
  }
}
