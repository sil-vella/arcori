/// Collects module WS handler registrations during bootstrap.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ws/contracts/ws_reconnect_contract.dart';
import '../ws/ws_channel_router.dart';
import 'contracts/app_state_sink.dart';

final AppStateSink appStateSink = _AppStateRegistry._instance;

void resetAppStateRegistry() => _AppStateRegistry._instance.clear();

/// Builds a [WsChannelRouter] with all module handlers registered.
///
/// Called from [WsConnectionManager.build] so handlers can use [Ref] to reach
/// module notifiers at message time.
WsChannelRouter buildWsChannelRouter(Ref ref) {
  final router = WsChannelRouter();
  final registrar = WsChannelRegistrar(router);
  for (final register in _AppStateRegistry._instance._wsRegistrations) {
    register(registrar, ref);
  }
  return router;
}

/// Runs module reconnect hooks after a socket is (re)established.
Future<void> runWsReconnectHooks(
  String connectionId,
  Ref ref,
  WsSendFrame send,
) async {
  for (final hook in _AppStateRegistry._instance._reconnectHooks) {
    await hook(connectionId, ref, send);
  }
}

class _AppStateRegistry implements AppStateSink {
  _AppStateRegistry._();

  static final _AppStateRegistry _instance = _AppStateRegistry._();

  final List<void Function(WsChannelRegistrar registrar, Ref ref)>
      _wsRegistrations = [];
  final List<WsReconnectHook> _reconnectHooks = [];

  void clear() {
    _wsRegistrations.clear();
    _reconnectHooks.clear();
  }

  @override
  void onWsReady(
    void Function(WsChannelRegistrar registrar, Ref ref) register,
  ) {
    _wsRegistrations.add(register);
  }

  @override
  void onWsReconnect(WsReconnectHook hook) {
    _reconnectHooks.add(hook);
  }
}
