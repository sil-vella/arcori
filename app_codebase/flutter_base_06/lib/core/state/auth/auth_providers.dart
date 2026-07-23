import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../errors/api_error.dart';
import '../../errors/auth_error_messages.dart';
import '../../http/auth_api_client.dart';
import '../../http/contracts/auth_api_contract.dart';
import '../../../utils/dev_logger.dart';
import '../contracts/auth_session_reader.dart';
import 'auth_state.dart';
import 'auth_token_storage.dart';
import 'contracts/auth_storage_contract.dart';
import 'contracts/local_user_storage_contract.dart';
import 'guest_credentials_factory.dart';
import 'local_user_storage.dart';
import '../../../modules/auth/auth_analytics.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

final authStorageProvider = Provider<AuthStorageContract>(
  (ref) => AuthTokenStorage(),
);

final localUserStorageProvider = Provider<LocalUserStorageContract>(
  (ref) => LocalUserStorage(),
);

final guestCredentialsFactoryProvider = Provider<GuestCredentialsFactory>(
  (ref) => GuestCredentialsFactory(),
);

final authApiClientProvider = Provider<AuthApiContract>(
  (ref) => AuthApiClient(),
);

/// Tier-1 session store: access + refresh tokens and user id.
class AuthNotifier extends Notifier<AuthState> implements AuthSessionReader {
  AuthStorageContract get _storage => ref.read(authStorageProvider);
  LocalUserStorageContract get _localUser => ref.read(localUserStorageProvider);
  GuestCredentialsFactory get _guestFactory =>
      ref.read(guestCredentialsFactoryProvider);
  AuthApiContract get _api => ref.read(authApiClientProvider);

  @override
  AuthState build() => const AuthState();

  @override
  bool get isAuthenticated => state.isAuthenticated;

  @override
  String? get accessToken => state.accessToken;

  @override
  String? get userId => state.userId;

  /// Restore session from secure storage; refresh, login, or guest-register.
  Future<void> bootstrap() async {
    if (LOGGING_SWITCH) {
      customlog('AuthNotifier.bootstrap: started');
    }
    try {
      final stored = await _storage.read();
      if (LOGGING_SWITCH) {
        customlog(
          'AuthNotifier.bootstrap: stored session ${stored == null ? 'absent' : 'present'}',
        );
      }
      if (stored != null) {
        try {
          final refreshed = await _api.refreshAccessToken(stored.refreshToken);
          if (refreshed != null) {
            if (LOGGING_SWITCH) {
              customlog('AuthNotifier.bootstrap: refreshed stored session');
            }
            await _persistSession(
              userId: refreshed.userId,
              accessToken: refreshed.accessToken,
              refreshToken: refreshed.refreshToken,
              isGuest: refreshed.isGuest,
            );
            return;
          }
        } catch (e) {
          if (LOGGING_SWITCH) {
            customlog('AuthNotifier.bootstrap: refresh error: $e');
          }
        }
        await _storage.clear();
      }

      final profile = await _localUser.read();
      if (LOGGING_SWITCH) {
        customlog(
          'AuthNotifier.bootstrap: local profile ${profile == null ? 'absent' : profile.email}',
        );
      }
      if (profile != null) {
        final outcome = await _loginWithProfile(profile);
        if (outcome.isSuccess) {
          if (LOGGING_SWITCH) {
            customlog('AuthNotifier.bootstrap: logged in from local profile');
          }
          return;
        }
        if (_shouldRecoverOrphanedGuest(
          outcome,
          profile.email,
          isGuestProfile: profile.isGuest,
        )) {
          if (LOGGING_SWITCH) {
            customlog(
              'AuthNotifier.bootstrap: orphaned guest — clearing secure '
              'auth profile and re-registering',
            );
          }
          await _recoverOrphanedGuest();
          return;
        }
        if (LOGGING_SWITCH) {
          customlog(
            'AuthNotifier.bootstrap: local profile login failed — '
            'keeping stored credentials',
          );
        }
        state = state.copyWith(
          sessionStatus: SessionStatus.unauthenticated,
          errorMessage: userMessageForAuthFailure(
            apiError: outcome.error,
            isNetworkError: outcome.isNetworkError,
          ),
        );
        return;
      }

      if (LOGGING_SWITCH) {
        customlog('AuthNotifier.bootstrap: no local profile — registering guest');
      }
      await _registerGuest(fromAutoBootstrap: true);
    } finally {
      if (state.sessionStatus == SessionStatus.unknown) {
        if (LOGGING_SWITCH) {
          customlog(
            'AuthNotifier.bootstrap: session still unknown — marking unauthenticated',
          );
        }
        state = state.copyWith(
          sessionStatus: SessionStatus.unauthenticated,
          errorMessage: state.errorMessage ?? 'Session bootstrap incomplete',
        );
      }
      if (LOGGING_SWITCH) {
        customlog(
          'AuthNotifier.bootstrap: done '
          'sessionStatus=${state.sessionStatus} '
          'isAuthenticated=${state.isAuthenticated}',
        );
      }
    }
  }

  Future<void> devLogin({String userId = 'flutter-ws-demo'}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.devLogin(userId);
      if (result == null) {
        state = state.copyWith(
          isLoading: false,
          sessionStatus: SessionStatus.unauthenticated,
          errorMessage: 'dev-login failed',
        );
        return;
      }
      await _persistSession(
        userId: result.userId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        isGuest: result.isGuest,
      );
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        sessionStatus: SessionStatus.unauthenticated,
        errorMessage: 'dev-login error: $e',
      );
    }
  }

  /// Returns true when a new access token was obtained.
  Future<bool> refreshAccessToken() async {
    final refreshToken = state.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    try {
      final result = await _api.refreshAccessToken(refreshToken);
      if (result == null) {
        if (LOGGING_SWITCH) {
          customlog('auth refresh failed: null response');
        }
        return false;
      }
      await _persistSession(
        userId: result.userId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        isGuest: result.isGuest,
      );
      return true;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('auth refresh error: $e');
      }
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = state.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _api.logout(refreshToken);
      } catch (e) {
        if (LOGGING_SWITCH) {
          customlog('auth logout revoke error: $e');
        }
      }
    }
    await _storage.clear();
    state = const AuthState(sessionStatus: SessionStatus.unauthenticated);
  }

  /// Permanently delete the signed-in account; clears local session and profile.
  Future<bool> deleteAccount({
    required String password,
    required String confirmation,
  }) async {
    final accessToken = state.accessToken;
    if (accessToken == null || accessToken.isEmpty || !state.isAuthenticated) {
      state = state.copyWith(
        errorMessage: 'Sign in to delete your account',
      );
      return false;
    }
    if (state.isGuest) {
      state = state.copyWith(
        errorMessage: 'Guest accounts cannot be deleted. Create a full account first.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final outcome = await _api.deleteAccount(
        accessToken: accessToken,
        password: password.trim(),
        confirmation: confirmation.trim(),
      );
      if (!outcome.isSuccess) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: userMessageForAuthFailure(
            apiError: outcome.error,
            isNetworkError: outcome.isNetworkError,
          ),
        );
        return false;
      }
      await _storage.clear();
      await _localUser.clear();
      state = const AuthState(sessionStatus: SessionStatus.unauthenticated);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: userMessageForAuthFailure(isNetworkError: false),
      );
      return false;
    }
  }

  /// Sign in with email/password; optionally refresh secure local profile.
  Future<bool> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    if (state.isAuthenticated) {
      return true;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Email and password are required',
      );
      return false;
    }

    try {
      await AuthAnalytics.logLoginAttempt();
      final outcome = await _api.login(
        email: normalizedEmail,
        password: normalizedPassword,
      );
      if (!outcome.isSuccess) {
        if (_shouldRecoverOrphanedGuest(outcome, normalizedEmail)) {
          if (LOGGING_SWITCH) {
            customlog(
              'AuthNotifier.loginWithCredentials: orphaned guest — clearing '
              'secure auth profile and re-registering',
            );
          }
          await _recoverOrphanedGuest();
          state = state.copyWith(
            isLoading: false,
            clearError: state.isAuthenticated,
          );
          return state.isAuthenticated;
        }
        state = state.copyWith(
          isLoading: false,
          sessionStatus: state.isAuthenticated
              ? SessionStatus.authenticated
              : SessionStatus.unauthenticated,
          errorMessage: userMessageForAuthFailure(
            apiError: outcome.error,
            isNetworkError: outcome.isNetworkError,
          ),
        );
        return false;
      }
      final result = outcome.value!;

      final existing = await _localUser.read();
      await _localUser.write(
        StoredLocalUser(
          username: existing?.username ?? normalizedEmail.split('@').first,
          email: normalizedEmail,
          password: normalizedPassword,
          isGuest: result.isGuest,
        ),
      );
      await _persistSession(
        userId: result.userId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        isGuest: result.isGuest,
      );
      state = state.copyWith(isLoading: false, clearError: true);
      await AuthAnalytics.logLoginSuccess();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: userMessageForAuthFailure(isNetworkError: false),
      );
      return false;
    }
  }

  /// Register a full account (non-guest) and establish a session.
  Future<bool> registerAccount({
    required String username,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final normalizedUsername = username.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    if (normalizedUsername.isEmpty ||
        normalizedEmail.isEmpty ||
        normalizedPassword.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Username, email, and password are required',
      );
      return false;
    }

    try {
      var outcome = await _api.register(
        username: normalizedUsername,
        email: normalizedEmail,
        password: normalizedPassword,
        isGuest: false,
      );
      if (!outcome.isSuccess) {
        outcome = await _api.login(
          email: normalizedEmail,
          password: normalizedPassword,
        );
      }
      if (!outcome.isSuccess) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: userMessageForAuthFailure(
            apiError: outcome.error,
            isNetworkError: outcome.isNetworkError,
          ),
        );
        return false;
      }
      final result = outcome.value!;

      await _localUser.write(
        StoredLocalUser(
          username: normalizedUsername,
          email: normalizedEmail,
          password: normalizedPassword,
          isGuest: result.isGuest,
        ),
      );
      await _persistSession(
        userId: result.userId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        isGuest: result.isGuest,
      );
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: userMessageForAuthFailure(isNetworkError: false),
      );
      return false;
    }
  }

  /// Upgrade the signed-in guest account in-place (same user id).
  Future<bool> convertGuestAccount({
    required String guestEmail,
    required String username,
    required String email,
    required String password,
  }) async {
    final accessToken = state.accessToken;
    if (accessToken == null || accessToken.isEmpty || !state.isAuthenticated) {
      state = state.copyWith(
        errorMessage: 'Sign in as a guest to convert your account',
      );
      return false;
    }
    if (!state.isGuest) {
      if (LOGGING_SWITCH) {
        customlog('AuthNotifier.convertGuestAccount: rejected — not a guest');
      }
      state = state.copyWith(
        errorMessage: 'Only guest accounts can be converted',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final normalizedGuestEmail = guestEmail.trim().toLowerCase();
    final normalizedUsername = username.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    if (LOGGING_SWITCH) {
      customlog(
        'AuthNotifier.convertGuestAccount: started userId=${state.userId} '
        'guestEmail=$normalizedGuestEmail newEmail=$normalizedEmail '
        'username=$normalizedUsername',
      );
    }
    if (normalizedGuestEmail.isEmpty ||
        normalizedUsername.isEmpty ||
        normalizedEmail.isEmpty ||
        normalizedPassword.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'All fields are required',
      );
      return false;
    }

    try {
      final outcome = await _api.convertGuestAccount(
        accessToken: accessToken,
        guestEmail: normalizedGuestEmail,
        username: normalizedUsername,
        email: normalizedEmail,
        password: normalizedPassword,
      );
      if (!outcome.isSuccess) {
        if (LOGGING_SWITCH) {
          customlog(
            'AuthNotifier.convertGuestAccount: failed '
            'network=${outcome.isNetworkError} code=${outcome.error?.rawCode}',
          );
        }
        state = state.copyWith(
          isLoading: false,
          errorMessage: userMessageForAuthFailure(
            apiError: outcome.error,
            isNetworkError: outcome.isNetworkError,
          ),
        );
        return false;
      }
      final result = outcome.value!;

      await _localUser.write(
        StoredLocalUser(
          username: normalizedUsername,
          email: normalizedEmail,
          password: normalizedPassword,
          isGuest: false,
        ),
      );
      await _persistSession(
        userId: result.userId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        isGuest: false,
      );
      state = state.copyWith(isLoading: false, clearError: true);
      if (LOGGING_SWITCH) {
        customlog(
          'AuthNotifier.convertGuestAccount: success userId=${result.userId} '
          'isGuest=false',
        );
      }
      await AuthAnalytics.logGuestConvertSuccess();
      return true;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('AuthNotifier.convertGuestAccount: error $e');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: userMessageForAuthFailure(isNetworkError: false),
      );
      return false;
    }
  }

  Future<AuthApiOutcome<AuthLoginResult>> _loginWithProfile(
    StoredLocalUser profile,
  ) async {
    final outcome = await _api.login(
      email: profile.email,
      password: profile.password,
    );
    if (!outcome.isSuccess) {
      if (LOGGING_SWITCH) {
        customlog(
          'auth login failed for ${profile.email} '
          'network=${outcome.isNetworkError} code=${outcome.error?.rawCode}',
        );
      }
      if (outcome.isNetworkError) {
        return const AuthApiOutcome.networkFailure();
      }
      return AuthApiOutcome.failure(
        error: outcome.error ??
            ApiError(
              code: CoreApiErrorCode.unauthorized,
              message: 'Invalid email or password',
              rawCode: 'unauthorized',
            ),
      );
    }
    await _persistSession(
      userId: outcome.value!.userId,
      accessToken: outcome.value!.accessToken,
      refreshToken: outcome.value!.refreshToken,
      isGuest: outcome.value!.isGuest,
    );
    return AuthApiOutcome.success(outcome.value!);
  }

  Future<void> _registerGuest({bool fromAutoBootstrap = false}) async {
    if (LOGGING_SWITCH) {
      customlog('AuthNotifier._registerGuest: started');
    }
    final guest = _guestFactory.generate();

    try {
      var outcome = await _api.register(
        username: guest.username,
        email: guest.email,
        password: guest.password,
        isGuest: true,
      );
      if (!outcome.isSuccess && LOGGING_SWITCH) {
        customlog(
          'AuthNotifier._registerGuest: register failed, trying login',
        );
      }
      if (!outcome.isSuccess) {
        outcome = await _api.login(
          email: guest.email,
          password: guest.password,
        );
      }
      if (!outcome.isSuccess) {
        if (LOGGING_SWITCH) {
          customlog('AuthNotifier._registerGuest: failed — no session from API');
        }
        state = state.copyWith(
          sessionStatus: SessionStatus.unauthenticated,
          errorMessage: userMessageForAuthFailure(
            apiError: outcome.error,
            isNetworkError: outcome.isNetworkError,
          ),
        );
        return;
      }
      final result = outcome.value!;
      await _localUser.write(guest);
      if (LOGGING_SWITCH) {
        customlog(
          'AuthNotifier._registerGuest: stored local profile username=${guest.username}',
        );
      }
      if (LOGGING_SWITCH) {
        customlog(
          'AuthNotifier._registerGuest: success userId=${result.userId} '
          'isGuest=${result.isGuest}',
        );
      }
      await _persistSession(
        userId: result.userId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        isGuest: result.isGuest,
      );
      if (fromAutoBootstrap) {
        await AuthAnalytics.logGuestBootstrapCreated();
      }
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('AuthNotifier._registerGuest: error $e');
      }
      state = state.copyWith(
        sessionStatus: SessionStatus.unauthenticated,
        errorMessage: userMessageForAuthFailure(isNetworkError: false),
      );
    }
  }

  Future<void> _persistSession({
    required String userId,
    required String accessToken,
    required String refreshToken,
    bool isGuest = false,
  }) async {
    await _storage.write(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
    );
    state = AuthState(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      isGuest: isGuest,
      sessionStatus: SessionStatus.authenticated,
    );
  }

  bool _isInvalidCredentials(AuthApiOutcome<AuthLoginResult> outcome) {
    final code = outcome.error?.rawCode;
    return code == 'invalid_credentials' || code == 'unauthorized';
  }

  bool _isGuestEmail(String email) =>
      email.trim().toLowerCase().endsWith('@arcori.arcori');

  bool _shouldRecoverOrphanedGuest(
    AuthApiOutcome<AuthLoginResult> outcome,
    String email, {
    bool isGuestProfile = false,
  }) {
    return (isGuestProfile || _isGuestEmail(email)) &&
        !outcome.isNetworkError &&
        _isInvalidCredentials(outcome);
  }

  Future<void> _recoverOrphanedGuest() async {
    await _storage.clear();
    await _localUser.clear();
    await _registerGuest();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Read-only contract accessor for modules that depend on [AuthSessionReader].
final authSessionReaderProvider = Provider<AuthSessionReader>(
  (ref) => ref.watch(authProvider.notifier),
);
