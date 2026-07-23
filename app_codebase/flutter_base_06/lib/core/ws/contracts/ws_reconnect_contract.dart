import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Send helper passed to [WsReconnectHook] after a connection is restored.
typedef WsSendFrame = Future<void> Function({
  required String type,
  required String channel,
  Map<String, dynamic>? payload,
});

/// Module hook — re-subscribe rooms, resume streams, etc. after reconnect.
typedef WsReconnectHook = Future<void> Function(
  String connectionId,
  Ref ref,
  WsSendFrame send,
);
