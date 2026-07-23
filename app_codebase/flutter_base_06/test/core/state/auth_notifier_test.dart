import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arcori/core/errors/api_error.dart';
import 'package:arcori/core/http/contracts/auth_api_contract.dart';
import 'package:arcori/core/state/auth/auth_providers.dart';
import 'package:arcori/core/state/auth/contracts/auth_storage_contract.dart';
import 'package:arcori/core/state/auth/contracts/local_user_storage_contract.dart';
import 'package:arcori/core/state/auth/guest_credentials_factory.dart';

class _MemoryAuthStorage implements AuthStorageContract {
  StoredAuthSession? session;

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<StoredAuthSession?> read() async => session;

  @override
  Future<void> write({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    session = StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
    );
  }
}

class _MemoryLocalUserStorage implements LocalUserStorageContract {
  StoredLocalUser? user;

  @override
  Future<void> clear() async {
    user = null;
  }

  @override
  Future<StoredLocalUser?> read() async => user;

  @override
  Future<void> write(StoredLocalUser value) async {
    user = value;
  }
}

class _FakeAuthApi implements AuthApiContract {
  int registerCalls = 0;
  int loginCalls = 0;

  @override
  Future<AuthLoginResult?> devLogin(String userId) async {
    return AuthLoginResult(
      userId: userId,
      accessToken: 'access',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<AuthApiOutcome<AuthLoginResult>> register({
    required String username,
    required String email,
    required String password,
    bool isGuest = false,
  }) async {
    registerCalls++;
    return AuthApiOutcome.success(
      AuthLoginResult(
        userId: 'guest-user-id',
        accessToken: 'access',
        refreshToken: 'refresh',
        isGuest: isGuest,
      ),
    );
  }

  bool loginShouldFail = false;
  bool loginNetworkError = false;
  String loginFailureCode = 'invalid_credentials';

  @override
  Future<AuthApiOutcome<AuthLoginResult>> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (loginShouldFail) {
      if (loginNetworkError) {
        return const AuthApiOutcome.networkFailure();
      }
      return AuthApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.unauthorized,
          message: 'Invalid email or password',
          rawCode: loginFailureCode,
        ),
      );
    }
    return AuthApiOutcome.success(
      AuthLoginResult(
        userId: 'existing-user-id',
        accessToken: 'access',
        refreshToken: 'refresh',
        isGuest: true,
      ),
    );
  }

  @override
  Future<AuthRefreshResult?> refreshAccessToken(String refreshToken) async {
    if (refreshToken.isEmpty) return null;
    return const AuthRefreshResult(
      userId: 'user-1',
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      isGuest: true,
    );
  }

  int logoutCalls = 0;

  @override
  Future<void> logout(String refreshToken) async {
    logoutCalls++;
  }

  @override
  Future<AuthApiOutcome<bool>> deleteAccount({
    required String accessToken,
    required String password,
    required String confirmation,
  }) async {
    return const AuthApiOutcome.success(true);
  }

  int convertGuestCalls = 0;
  bool convertGuestShouldFail = false;
  String convertGuestFailureCode = 'forbidden';
  String convertGuestUserId = 'guest-user-id';

  @override
  Future<AuthApiOutcome<AuthLoginResult>> convertGuestAccount({
    required String accessToken,
    required String guestEmail,
    required String username,
    required String email,
    required String password,
  }) async {
    convertGuestCalls++;
    if (convertGuestShouldFail) {
      return AuthApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.forbidden,
          message: 'Only guest accounts can be converted',
          rawCode: convertGuestFailureCode,
        ),
      );
    }
    return AuthApiOutcome.success(
      AuthLoginResult(
        userId: convertGuestUserId,
        accessToken: 'full-access',
        refreshToken: 'full-refresh',
        isGuest: false,
      ),
    );
  }

  @override
  Future<AuthApiOutcome<bool>> verifyEmail({required String token}) async {
    return const AuthApiOutcome.success(true);
  }
}

void main() {
  group('AuthNotifier', () {
    test('initial state is bootstrapping', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(authProvider).isBootstrapping, isTrue);
    });

    test('bootstrap with no storage registers guest', () async {
      final storage = _MemoryAuthStorage();
      final localUser = _MemoryLocalUserStorage();
      final api = _FakeAuthApi();
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(storage),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
          guestCredentialsFactoryProvider.overrideWithValue(
            GuestCredentialsFactory(random: Random(42)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isGuest, isTrue);
      expect(auth.userId, 'guest-user-id');
      expect(api.registerCalls, 1);
      expect(localUser.user?.username.startsWith('guest'), isTrue);
    });

    test('bootstrap with stored tokens refreshes session', () async {
      final storage = _MemoryAuthStorage();
      await storage.write(
        accessToken: 'old-access',
        refreshToken: 'refresh',
        userId: 'user-1',
      );
      final api = _FakeAuthApi();
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(storage),
          localUserStorageProvider.overrideWithValue(_MemoryLocalUserStorage()),
          authApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.accessToken, 'new-access');
      expect(api.registerCalls, 0);
      expect(api.loginCalls, 0);
    });

    test('bootstrap with local profile logs in', () async {
      final localUser = _MemoryLocalUserStorage();
      await localUser.write(
        const StoredLocalUser(
          username: 'guestabc',
          email: 'guestabc@arcori.arcori',
          password: 'guestabc123456',
          isGuest: true,
        ),
      );
      final api = _FakeAuthApi();
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(_MemoryAuthStorage()),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.userId, 'existing-user-id');
      expect(api.loginCalls, 1);
      expect(api.registerCalls, 0);
    });

    test('bootstrap orphaned guest re-registers after invalid_credentials', () async {
      final localUser = _MemoryLocalUserStorage();
      const storedProfile = StoredLocalUser(
        username: 'guestabc',
        email: 'guestabc@arcori.arcori',
        password: 'guestabc123456',
        isGuest: true,
      );
      await localUser.write(storedProfile);
      final api = _FakeAuthApi()..loginShouldFail = true;
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(_MemoryAuthStorage()),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
          guestCredentialsFactoryProvider.overrideWithValue(
            GuestCredentialsFactory(random: Random(42)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isGuest, isTrue);
      expect(api.loginCalls, 1);
      expect(api.registerCalls, 1);
      expect(localUser.user, isNot(storedProfile));
      expect(localUser.user?.username.startsWith('guest'), isTrue);
    });

    test('bootstrap full account login failure keeps profile', () async {
      final localUser = _MemoryLocalUserStorage();
      const storedProfile = StoredLocalUser(
        username: 'myuser',
        email: 'myuser@example.com',
        password: 'secret123456',
        isGuest: false,
      );
      await localUser.write(storedProfile);
      final api = _FakeAuthApi()..loginShouldFail = true;
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(_MemoryAuthStorage()),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, isNotNull);
      expect(api.loginCalls, 1);
      expect(api.registerCalls, 0);
      expect(localUser.user, storedProfile);
    });

    test('bootstrap login network error notifies without replacing guest', () async {
      final localUser = _MemoryLocalUserStorage();
      const storedProfile = StoredLocalUser(
        username: 'guestabc',
        email: 'guestabc@arcori.arcori',
        password: 'guestabc123456',
        isGuest: true,
      );
      await localUser.write(storedProfile);
      final api = _FakeAuthApi()
        ..loginShouldFail = true
        ..loginNetworkError = true;
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(_MemoryAuthStorage()),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('Cannot reach the server'));
      expect(api.registerCalls, 0);
      expect(localUser.user, storedProfile);
    });

    test('loginWithCredentials orphaned guest re-registers', () async {
      final localUser = _MemoryLocalUserStorage();
      const storedProfile = StoredLocalUser(
        username: 'guestabc',
        email: 'guestabc@arcori.arcori',
        password: 'guestabc123456',
        isGuest: true,
      );
      await localUser.write(storedProfile);
      final api = _FakeAuthApi()..loginShouldFail = true;
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(_MemoryAuthStorage()),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
          guestCredentialsFactoryProvider.overrideWithValue(
            GuestCredentialsFactory(random: Random(99)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container.read(authProvider.notifier).loginWithCredentials(
            email: storedProfile.email,
            password: storedProfile.password,
          );
      final auth = container.read(authProvider);
      expect(ok, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isGuest, isTrue);
      expect(api.loginCalls, 1);
      expect(api.registerCalls, 1);
      expect(localUser.user, isNot(storedProfile));
    });

    test('loginWithCredentials full account failure keeps profile', () async {
      final localUser = _MemoryLocalUserStorage();
      const storedProfile = StoredLocalUser(
        username: 'myuser',
        email: 'myuser@example.com',
        password: 'secret123456',
        isGuest: false,
      );
      await localUser.write(storedProfile);
      final api = _FakeAuthApi()..loginShouldFail = true;
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(_MemoryAuthStorage()),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container.read(authProvider.notifier).loginWithCredentials(
            email: storedProfile.email,
            password: 'wrong-password',
          );
      expect(ok, isFalse);
      expect(api.registerCalls, 0);
      expect(localUser.user, storedProfile);
    });

    test('convertGuestAccount success updates session and local profile', () async {
      final storage = _MemoryAuthStorage();
      await storage.write(
        accessToken: 'guest-access',
        refreshToken: 'guest-refresh',
        userId: 'user-1',
      );
      final localUser = _MemoryLocalUserStorage();
      await localUser.write(
        const StoredLocalUser(
          username: 'guestabc',
          email: 'guestabc@arcori.arcori',
          password: 'guestabc123456',
          isGuest: true,
        ),
      );
      final api = _FakeAuthApi()..convertGuestUserId = 'user-1';
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(storage),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final ok = await container.read(authProvider.notifier).convertGuestAccount(
            guestEmail: 'guestabc@arcori.arcori',
            username: 'myuser',
            email: 'myuser@example.com',
            password: 'secret123456',
          );
      final auth = container.read(authProvider);
      expect(ok, isTrue);
      expect(auth.isGuest, isFalse);
      expect(auth.userId, 'user-1');
      expect(auth.accessToken, 'full-access');
      expect(api.convertGuestCalls, 1);
      expect(localUser.user?.isGuest, isFalse);
      expect(localUser.user?.email, 'myuser@example.com');
    });

    test('convertGuestAccount failure keeps guest session', () async {
      final storage = _MemoryAuthStorage();
      await storage.write(
        accessToken: 'guest-access',
        refreshToken: 'guest-refresh',
        userId: 'user-1',
      );
      final localUser = _MemoryLocalUserStorage();
      const storedProfile = StoredLocalUser(
        username: 'guestabc',
        email: 'guestabc@arcori.arcori',
        password: 'guestabc123456',
        isGuest: true,
      );
      await localUser.write(storedProfile);
      final api = _FakeAuthApi()
        ..convertGuestShouldFail = true
        ..convertGuestFailureCode = 'email_taken';
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(storage),
          localUserStorageProvider.overrideWithValue(localUser),
          authApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final ok = await container.read(authProvider.notifier).convertGuestAccount(
            guestEmail: storedProfile.email,
            username: 'myuser',
            email: 'taken@example.com',
            password: 'secret123456',
          );
      final auth = container.read(authProvider);
      expect(ok, isFalse);
      expect(auth.isGuest, isTrue);
      expect(auth.userId, 'user-1');
      expect(localUser.user, storedProfile);
    });

    test('logout clears session', () async {
      final storage = _MemoryAuthStorage();
      final api = _FakeAuthApi();
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(storage),
          localUserStorageProvider.overrideWithValue(_MemoryLocalUserStorage()),
          authApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).devLogin();
      expect(container.read(authProvider).isAuthenticated, isTrue);

      await container.read(authProvider.notifier).logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(await storage.read(), isNull);
      expect(api.logoutCalls, 1);
    });
  });
}
