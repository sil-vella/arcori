/// Bootstrap registration for module-owned state and WebSocket channel handlers.
///
/// Sinks are for startup wiring only — not runtime read/write of gameplay data.
/// Handlers receive [Ref] when [WsConnectionManager] starts inside [ProviderScope].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ws/contracts/ws_reconnect_contract.dart';
import '../../ws/ws_channel_router.dart';

abstract interface class AppStateSink {
  /// Register inbound WS handlers against [WsChannelRegistrar] prefixes.
  ///
  /// [Ref] is supplied at runtime when the channel router is built — use
  /// `ref.read(myProvider.notifier)` inside handlers, not static bridges.
  void onWsReady(
    void Function(WsChannelRegistrar registrar, Ref ref) register,
  );

  /// Register logic to run after a connection is (re)opened — e.g. room re-subscribe.
  void onWsReconnect(WsReconnectHook hook);
}
