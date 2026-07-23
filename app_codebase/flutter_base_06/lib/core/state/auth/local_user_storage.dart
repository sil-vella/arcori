import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'contracts/local_user_storage_contract.dart';

/// Secure local user profile storage (username, email, password, isGuest).
class LocalUserStorage implements LocalUserStorageContract {
  LocalUserStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _usernameKey = 'arcori_local_username';
  static const _emailKey = 'arcori_local_email';
  static const _passwordKey = 'arcori_local_password';
  static const _isGuestKey = 'arcori_local_is_guest';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredLocalUser?> read() async {
    final username = await _storage.read(key: _usernameKey);
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    final isGuestRaw = await _storage.read(key: _isGuestKey);
    if (username == null ||
        username.isEmpty ||
        email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return StoredLocalUser(
      username: username,
      email: email,
      password: password,
      isGuest: isGuestRaw == 'true',
    );
  }

  @override
  Future<void> write(StoredLocalUser user) async {
    await _storage.write(key: _usernameKey, value: user.username);
    await _storage.write(key: _emailKey, value: user.email);
    await _storage.write(key: _passwordKey, value: user.password);
    await _storage.write(key: _isGuestKey, value: user.isGuest ? 'true' : 'false');
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _isGuestKey);
  }
}
