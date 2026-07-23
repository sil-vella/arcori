import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_error.dart';
import '../errors/error_policy.dart';
import '../state/app_state_registry.dart';
import '../state/auth/auth_providers.dart';
import '../state/contracts/ws_connection_reader.dart';
import 'contracts/ws_client_contract.dart';
import 'contracts/ws_reconnect_contract.dart';
import 'ws_channel_router.dart';
import 'ws_client.dart';
import 'ws_reconnect_policy.dart';
import '../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = false; // ignore: constant_identifier_names

/// Registered endpoint — kept until intentional [disconnect].
class _WsEndpoint {
  const _WsEndpoint({required this.url});

  final String url;
}

/// Snapshot of managed WebSocket endpoints.
class WsConnectionSnapshot {
  const WsConnectionSnapshot({
    this.connections = const {},
    this.log = const [],
  });

  final Map<String, bool> connections;
  final List<String> log;

  WsConnectionSnapshot copyWith({
    Map<String, bool>? connections,
    List<String>? log,
  }) {
    return WsConnectionSnapshot(
      connections: connections ?? this.connections,
      log: log ?? this.log,
    );
  }
}

/// Tier-2 transport: shared WS clients, reconnect with backoff, channel demux.
class WsConnectionManager extends Notifier<WsConnectionSnapshot>
    implements WsConnectionReader {
  WsClientContract Function()? _clientFactoryOverride;
  WsReconnectPolicy _reconnectPolicy = defaultWsReconnectPolicy;

  final Map<String, WsClientContract> _clients = {};
  final Map<String, _WsEndpoint> _endpoints = {};
  final Map<String, StreamSubscription<Map<String, dynamic>>> _messageSubs = {};
  final Map<String, StreamSubscription<void>> _closedSubs = {};
  final Map<String, int> _reconnectAttempts = {};
  final Map<String, Timer> _reconnectTimers = {};
  WsChannelRouter? _channelRouter;

  /// Test hook — inject fake [WsClientContract] factory before first read.
  set clientFactoryForTest(WsClientContract Function()? factory) {
    _clientFactoryOverride = factory;
  }

  /// Test hook — shorten backoff delays.
  set reconnectPolicyForTest(WsReconnectPolicy policy) {
    _reconnectPolicy = policy;
  }

  WsClientContract _createClient() =>
      (_clientFactoryOverride ?? WsClient.new)();

  @override
  WsConnectionSnapshot build() {
    _channelRouter = buildWsChannelRouter(ref);
    ref.listen(authProvider, (previous, next) {
      final prevToken = previous?.accessToken;
      final nextToken = next.accessToken;
      if (prevToken != nextToken && next.isAuthenticated) {
        unawaited(reconnectAll());
      }
      if (!next.isAuthenticated) {
        unawaited(disconnectAll());
      }
    });
    ref.onDispose(_disposeAll);
    return const WsConnectionSnapshot();
  }

  @override
  bool isConnected(String connectionId) =>
      state.connections[connectionId] ?? false;

  @override
  Map<String, bool> get connectionStatus => state.connections;

  void _log(String line) {
    if (LOGGING_SWITCH) {
      customlog(line);
    }
    final next = [line, ...state.log].take(50).toList();
    state = state.copyWith(log: next);
  }

  /// Register endpoint and open the socket.
  Future<void> connect(
    String connectionId, {
    required String url,
    String? accessToken,
  }) async {
    _cancelReconnectTimer(connectionId);
    _endpoints[connectionId] = _WsEndpoint(url: url);
    await _openConnection(connectionId, accessToken: accessToken);
  }

  /// Stop reconnect loops and drop the endpoint.
  Future<void> disconnect(String connectionId) async {
    _cancelReconnectTimer(connectionId);
    _reconnectAttempts.remove(connectionId);
    _endpoints.remove(connectionId);
    await _tearDownClient(connectionId);
    _setConnected(connectionId, false);
  }

  Future<void> disconnectAll() async {
    for (final id in _endpoints.keys.toList()) {
      await disconnect(id);
    }
  }

  Future<void> reconnectAll() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    for (final id in _endpoints.keys.toList()) {
      _cancelReconnectTimer(id);
      await _openConnection(id, accessToken: token);
    }
  }

  Future<void> send(
    String connectionId, {
    required String type,
    required String channel,
    Map<String, dynamic>? payload,
  }) async {
    final client = _clients[connectionId];
    if (client == null) {
      throw StateError('$connectionId not connected');
    }
    await client.send(type: type, channel: channel, payload: payload);
    _log('$connectionId → $type/$channel');
  }

  Future<void> _openConnection(
    String connectionId, {
    String? accessToken,
  }) async {
    final endpoint = _endpoints[connectionId];
    if (endpoint == null) {
      return;
    }

    await _tearDownClient(connectionId);

    final client = _createClient();
    _clients[connectionId] = client;

    _messageSubs[connectionId] = client.messages.listen(
      (data) {
        _channelRouter?.dispatch(connectionId, data);
        _log('$connectionId ← $data');
      },
      onError: (Object error) => _handleError(connectionId, error),
    );

    _closedSubs[connectionId] = client.connectionClosed.listen((_) {
      unawaited(_onConnectionClosed(connectionId));
    });

    try {
      await client.connect(url: endpoint.url, accessToken: accessToken);
      _reconnectAttempts[connectionId] = 0;
      _setConnected(connectionId, true);
      _log('$connectionId connected → ${endpoint.url}');
      await _runReconnectHooks(connectionId);
    } catch (e) {
      _log('$connectionId connect error: $e');
      _setConnected(connectionId, false);
      _scheduleReconnect(connectionId);
    }
  }

  Future<void> _onConnectionClosed(String connectionId) async {
    if (!_endpoints.containsKey(connectionId)) {
      return;
    }
    _log('$connectionId socket closed — scheduling reconnect');
    _setConnected(connectionId, false);
    await _tearDownClient(connectionId);
    _scheduleReconnect(connectionId);
  }

  void _scheduleReconnect(String connectionId) {
    if (!_endpoints.containsKey(connectionId)) {
      return;
    }
    _cancelReconnectTimer(connectionId);

    final attempt = _reconnectAttempts[connectionId] ?? 0;
    final delay = _reconnectPolicy.delayForAttempt(attempt);
    _reconnectAttempts[connectionId] = attempt + 1;
    _log('$connectionId reconnect in ${delay.inMilliseconds}ms (attempt ${attempt + 1})');

    _reconnectTimers[connectionId] = Timer(delay, () {
      unawaited(_attemptReconnect(connectionId));
    });
  }

  Future<void> _attemptReconnect(String connectionId) async {
    if (!_endpoints.containsKey(connectionId)) {
      return;
    }
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      _log('$connectionId reconnect skipped — not authenticated');
      return;
    }
    await _openConnection(connectionId, accessToken: token);
  }

  void _cancelReconnectTimer(String connectionId) {
    _reconnectTimers.remove(connectionId)?.cancel();
  }

  Future<void> _runReconnectHooks(String connectionId) async {
    WsSendFrame send = ({
      required String type,
      required String channel,
      Map<String, dynamic>? payload,
    }) =>
        this.send(
          connectionId,
          type: type,
          channel: channel,
          payload: payload,
        );

    await runWsReconnectHooks(connectionId, ref, send);
  }

  Future<void> _handleError(String connectionId, Object error) async {
    _log('$connectionId error: $error');
    if (error is ApiError) {
      final action = actionForApiError(error, isWebSocket: true);
      if (action == ErrorAction.reconnectWs ||
          error.rawCode == 'token_expired') {
        await ref.read(authProvider.notifier).refreshAccessToken();
        if (!ref.read(authProvider).isAuthenticated) {
          await ref.read(authProvider.notifier).logout();
          return;
        }
        _cancelReconnectTimer(connectionId);
        final token = ref.read(authProvider).accessToken;
        await _openConnection(connectionId, accessToken: token);
      }
    }
  }

  void _setConnected(String connectionId, bool connected) {
    state = state.copyWith(
      connections: {...state.connections, connectionId: connected},
    );
  }

  Future<void> _tearDownClient(String connectionId) async {
    await _messageSubs.remove(connectionId)?.cancel();
    await _closedSubs.remove(connectionId)?.cancel();
    await _clients.remove(connectionId)?.disconnect();
  }

  void _disposeAll() {
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    for (final sub in _messageSubs.values) {
      sub.cancel();
    }
    _messageSubs.clear();
    for (final sub in _closedSubs.values) {
      sub.cancel();
    }
    _closedSubs.clear();
    for (final client in _clients.values) {
      client.disconnect();
    }
    _clients.clear();
    _endpoints.clear();
  }
}

final wsConnectionManagerProvider =
    NotifierProvider<WsConnectionManager, WsConnectionSnapshot>(
  WsConnectionManager.new,
);

final wsConnectionReaderProvider = Provider<WsConnectionReader>(
  (ref) => ref.watch(wsConnectionManagerProvider.notifier),
);
