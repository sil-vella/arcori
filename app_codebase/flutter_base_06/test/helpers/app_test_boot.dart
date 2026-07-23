import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arcori/app_init.dart';
import 'package:arcori/core/app_bar/app_bar_controller.dart';
import 'package:arcori/core/app_bar/app_bar_registry.dart';
import 'package:arcori/core/bottom_nav/bottom_nav_controller.dart';
import 'package:arcori/core/bottom_nav/bottom_nav_registry.dart';
import 'package:arcori/core/http/auth_api_client.dart';
import 'package:arcori/core/http/contracts/auth_api_contract.dart';
import 'package:arcori/core/navigation/app_drawer_registry.dart';
import 'package:arcori/core/navigation/app_router.dart';
import 'package:arcori/core/notifications/notification_screen_registry.dart';
import 'package:arcori/core/state/app_state_registry.dart';
import 'package:arcori/core/state/auth/auth_providers.dart';
import 'package:arcori/core/state/auth/auth_state.dart';
import 'package:arcori/core/state/auth/contracts/local_user_storage_contract.dart';
import 'package:arcori/core/state/auth/contracts/auth_storage_contract.dart';
import 'package:arcori/modules/module_registry.dart';

class _FakeAuthStorage implements AuthStorageContract {
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

class _FakeAuthApi implements AuthApiContract {
  @override
  Future<AuthLoginResult?> devLogin(String userId) async {
    return AuthLoginResult(
      userId: userId,
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
    );
  }

  @override
  Future<AuthApiOutcome<AuthLoginResult>> register({
    required String username,
    required String email,
    required String password,
    bool isGuest = false,
  }) async {
    return AuthApiOutcome.success(
      AuthLoginResult(
        userId: 'test-user',
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        isGuest: isGuest,
      ),
    );
  }

  @override
  Future<AuthApiOutcome<AuthLoginResult>> login({
    required String email,
    required String password,
  }) async {
    return AuthApiOutcome.success(
      AuthLoginResult(
        userId: 'test-user',
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
      ),
    );
  }

  @override
  Future<AuthRefreshResult?> refreshAccessToken(String refreshToken) async {
    if (refreshToken.isEmpty) return null;
    return const AuthRefreshResult(
      userId: 'test-user',
      accessToken: 'test-access',
      refreshToken: 'test-refresh-rotated',
    );
  }

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<AuthApiOutcome<bool>> deleteAccount({
    required String accessToken,
    required String password,
    required String confirmation,
  }) async {
    return const AuthApiOutcome.success(true);
  }

  @override
  Future<AuthApiOutcome<AuthLoginResult>> convertGuestAccount({
    required String accessToken,
    required String guestEmail,
    required String username,
    required String email,
    required String password,
  }) async {
    return AuthApiOutcome.success(
      AuthLoginResult(
        userId: 'test-user',
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        isGuest: false,
      ),
    );
  }

  @override
  Future<AuthApiOutcome<bool>> verifyEmail({required String token}) async {
    return const AuthApiOutcome.success(true);
  }
}

class _FakeLocalUserStorage implements LocalUserStorageContract {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredLocalUser?> read() async => null;

  @override
  Future<void> write(StoredLocalUser user) async {}
}

class TestAuthNotifier extends AuthNotifier {
  final SessionStatus initialStatus;
  final bool authenticated;

  TestAuthNotifier({
    this.initialStatus = SessionStatus.authenticated,
    this.authenticated = true,
  });

  @override
  Future<void> bootstrap() async {
    if (authenticated) {
      state = AuthState(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        userId: 'test-user',
        sessionStatus: SessionStatus.authenticated,
      );
      return;
    }
    state = AuthState(sessionStatus: initialStatus);
  }
}

List<Override> testAuthOverrides({bool authenticated = true}) {
  return [
    authStorageProvider.overrideWithValue(_FakeAuthStorage()),
    localUserStorageProvider.overrideWithValue(_FakeLocalUserStorage()),
    authApiClientProvider.overrideWithValue(_FakeAuthApi()),
    authProvider.overrideWith(
      () => TestAuthNotifier(authenticated: authenticated),
    ),
  ];
}

/// Mirrors [startApp] bootstrap without [runApp]; returns router for assertions.
Future<GoRouter> bootTestApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool authenticated = true,
}) async {
  resetAppRouteRegistry();
  resetAppDrawerRegistry();
  resetAppBarRegistry();
  resetBottomNavRegistry();
  resetAppStateRegistry();
  resetNotificationScreenRegistry();
  resetAppBarController();
  resetBottomNavController();
  registerApplicationModules(
    appRouteSink,
    appDrawerSink,
    appBarSink,
    bottomNavScopeSink,
    appStateSink,
    notificationScreenSink,
  );
  appBarController.setModuleItems(appBarModuleItems);
  bottomNavController.setModuleScopes(bottomNavModuleScopes);
  await tester.pumpWidget(
    rootAppForTesting(
      overrides: [...testAuthOverrides(authenticated: authenticated), ...overrides],
    ),
  );
  await tester.pumpAndSettle();
  final element = tester.element(find.byType(MaterialApp));
  final container = ProviderScope.containerOf(element);
  return container.read(appRouterProvider);
}

void resetAllRegistries() {
  resetAppRouteRegistry();
  resetAppDrawerRegistry();
  resetAppBarRegistry();
  resetBottomNavRegistry();
  resetAppStateRegistry();
  resetAppBarController();
  resetBottomNavController();
}
