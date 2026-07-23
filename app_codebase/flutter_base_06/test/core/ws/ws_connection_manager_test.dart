import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/http/contracts/auth_api_contract.dart';
import 'package:arcori/core/state/app_state_registry.dart';
import 'package:arcori/core/state/auth/auth_providers.dart';
import 'package:arcori/core/state/auth/auth_state.dart';
import 'package:arcori/core/state/auth/contracts/auth_storage_contract.dart';
import 'package:arcori/core/state/contracts/app_state_sink.dart';
import 'package:arcori/core/ws/contracts/ws_client_contract.dart';
import 'package:arcori/core/ws/contracts/ws_reconnect_contract.dart';
import 'package:arcori/core/ws/ws_connection_manager.dart';
import 'package:arcori/core/ws/ws_reconnect_policy.dart';

class _FakeWsClient implements WsClientContract {
  _FakeWsClient({this.failConnect = false});

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionClosed = StreamController<void>.broadcast();
  bool failConnect;
  bool connected = false;
  int connectCount = 0;

  @override
  Stream<void> get connectionClosed => _connectionClosed.stream;

  @override
  bool get isConnected => connected;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Future<void> connect({
    required String url,
    String? accessToken,
    String? serviceKey,
  }) async {
    connectCount += 1;
    if (failConnect) {
      throw StateError('connect failed');
    }
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<void> send({
    required String type,
    required String channel,
    Map<String, dynamic>? payload,
  }) async {}

  void simulateDrop() {
    connected = false;
    _connectionClosed.add(null);
  }
}

class _FakeAuthStorage implements AuthStorageContract {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredAuthSession?> read() async => null;

  @override
  Future<void> write({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {}
}

class _FakeAuthApi implements AuthApiContract {
  @override
  Future<AuthLoginResult?> devLogin(String userId) async => null;

  @override
  Future<AuthApiOutcome<AuthLoginResult>> register({
    required String username,
    required String email,
    required String password,
    bool isGuest = false,
  }) async =>
      const AuthApiOutcome.networkFailure();

  @override
  Future<AuthApiOutcome<AuthLoginResult>> login({
    required String email,
    required String password,
  }) async =>
      const AuthApiOutcome.networkFailure();

  @override
  Future<AuthRefreshResult?> refreshAccessToken(String refreshToken) async =>
      null;

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<AuthApiOutcome<bool>> deleteAccount({
    required String accessToken,
    required String password,
    required String confirmation,
  }) async =>
      const AuthApiOutcome.networkFailure();

  @override
  Future<AuthApiOutcome<AuthLoginResult>> convertGuestAccount({
    required String accessToken,
    required String guestEmail,
    required String username,
    required String email,
    required String password,
  }) async =>
      const AuthApiOutcome.networkFailure();

  @override
  Future<AuthApiOutcome<bool>> verifyEmail({required String token}) async =>
      const AuthApiOutcome.networkFailure();
}

class TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        accessToken: 'token',
        refreshToken: 'refresh',
        userId: 'user',
        sessionStatus: SessionStatus.authenticated,
      );
}

void main() {
  test('unexpected socket close schedules reconnect with backoff', () async {
    resetAppStateRegistry();
    final hooks = <String>[];
    appStateSink.onWsReconnect((connectionId, ref, send) async {
      hooks.add(connectionId);
    });

    final fake = _FakeWsClient();
    late WsConnectionManager manager;

    final container = ProviderContainer(
      overrides: [
        authStorageProvider.overrideWithValue(_FakeAuthStorage()),
        authApiClientProvider.overrideWithValue(_FakeAuthApi()),
        authProvider.overrideWith(TestAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    manager = container.read(wsConnectionManagerProvider.notifier);
    manager.clientFactoryForTest = () => fake;
    manager.reconnectPolicyForTest = const WsReconnectPolicy(
      initialDelay: Duration(milliseconds: 20),
      maxDelay: Duration(milliseconds: 20),
    );

    await manager.connect('dart', url: 'ws://test/ws', accessToken: 'token');
    expect(fake.connectCount, 1);
    expect(container.read(wsConnectionManagerProvider).connections['dart'], isTrue);

    fake.simulateDrop();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(wsConnectionManagerProvider).connections['dart'], isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fake.connectCount, greaterThan(1));
    expect(hooks, contains('dart'));
  });

  test('intentional disconnect cancels reconnect loop', () async {
    resetAppStateRegistry();
    final fake = _FakeWsClient();
    late WsConnectionManager manager;

    final container = ProviderContainer(
      overrides: [
        authStorageProvider.overrideWithValue(_FakeAuthStorage()),
        authApiClientProvider.overrideWithValue(_FakeAuthApi()),
        authProvider.overrideWith(TestAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    manager = container.read(wsConnectionManagerProvider.notifier);
    manager.clientFactoryForTest = () => fake;
    manager.reconnectPolicyForTest = const WsReconnectPolicy(
      initialDelay: Duration(milliseconds: 30),
    );

    await manager.connect('dart', url: 'ws://test/ws', accessToken: 'token');
    final countAfterConnect = fake.connectCount;

    fake.simulateDrop();
    await manager.disconnect('dart');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(fake.connectCount, countAfterConnect);
  });
}
