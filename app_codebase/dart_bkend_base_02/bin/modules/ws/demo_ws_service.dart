/// Demo WebSocket channel handlers — ping/pong and echo.
library;

import '../../core/state/room/room_demo_handler.dart';
import '../../core/ws/contracts/ws_message_contract.dart';

Map<String, dynamic>? handleSystem(
  WsConnectionContext ctx,
  WsClientMessage msg,
) {
  if (msg.msgType == 'ping') {
    return {
      'type': 'pong',
      'channel': 'system',
      'ts': DateTime.now().toUtc().toIso8601String(),
    };
  }
  return null;
}

Map<String, dynamic>? handleDemoEcho(
  WsConnectionContext ctx,
  WsClientMessage msg,
) {
  if (msg.msgType == 'event') {
    final text = msg.payload['text']?.toString() ?? '';
    return {
      'type': 'event',
      'channel': 'demo/echo',
      'payload': {'echo': text},
    };
  }
  return null;
}

Map<String, dynamic>? handleDemoRoom(
  WsConnectionContext ctx,
  WsClientMessage msg,
) =>
    handleDemoRoomMessage(ctx, msg);
