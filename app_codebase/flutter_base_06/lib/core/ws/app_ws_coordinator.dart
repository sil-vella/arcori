import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth/auth_providers.dart';
import 'app_ws_constants.dart';
import 'ws_config.dart';
import 'ws_connection_manager.dart';

/// Keeps the app-wide FastAPI WebSocket connected while authenticated.
final appWsCoordinatorProvider = Provider<void>((ref) {
  ref.listen(authProvider, (previous, next) {
    if (next.isBootstrapping) {
      return;
    }
    if (next.isAuthenticated) {
      unawaited(_connectAppApiWs(ref));
      return;
    }
  });

  final auth = ref.watch(authProvider);
  if (!auth.isBootstrapping && auth.isAuthenticated) {
    unawaited(_connectAppApiWs(ref));
  }
});

Future<void> _connectAppApiWs(Ref ref) async {
  final url = WsConfig.apiAuthuserUrl;
  if (url.isEmpty) {
    return;
  }
  final token = ref.read(authProvider).accessToken;
  if (token == null || token.isEmpty) {
    return;
  }
  final manager = ref.read(wsConnectionManagerProvider.notifier);
  if (manager.isConnected(kAppApiWsConnectionId)) {
    return;
  }
  await manager.connect(
    kAppApiWsConnectionId,
    url: url,
    accessToken: token,
  );
}

/// Reconnect all registered endpoints (including app api WS).
Future<void> reconnectAppWebSockets(WidgetRef ref) async {
  await ref.read(wsConnectionManagerProvider.notifier).reconnectAll();
}
