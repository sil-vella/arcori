/// Shared demo/room subscribe, unsubscribe, and broadcast logic.
library;

import '../../errors/app_error.dart';
import '../../ws/contracts/ws_message_contract.dart';
import '../../../modules/ops/ops_errors.dart';
import '../../../modules/ops/ops_state.dart';
import '../state_registry.dart';

const defaultDemoRoomId = 'demo';

Map<String, dynamic>? handleDemoRoomMessage(
  WsConnectionContext ctx,
  WsClientMessage msg,
) {
  final roomId = msg.payload['room_id']?.toString().trim().isNotEmpty == true
      ? msg.payload['room_id'].toString()
      : defaultDemoRoomId;

  if (msg.msgType == 'subscribe') {
    if (drainMode) {
      throw AppError(drainModeError);
    }
    roomRegistry.subscribe(roomId, ctx.connectionId, userId: ctx.userId);
    roomBroadcaster.broadcastToRoom(
      roomId,
      channel: 'demo/room',
      type: 'event',
      payload: {
        'event': 'member_joined',
        'room_id': roomId,
        'user_id': ctx.userId,
      },
      excludeConnectionId: ctx.connectionId,
    );
    return {
      'type': 'subscribed',
      'channel': 'demo/room',
      'payload': {'room_id': roomId},
    };
  }

  if (msg.msgType == 'unsubscribe') {
    roomRegistry.unsubscribe(roomId, ctx.connectionId);
    roomBroadcaster.broadcastToRoom(
      roomId,
      channel: 'demo/room',
      type: 'event',
      payload: {
        'event': 'member_left',
        'room_id': roomId,
        'user_id': ctx.userId,
      },
      excludeConnectionId: ctx.connectionId,
    );
    return {
      'type': 'unsubscribed',
      'channel': 'demo/room',
      'payload': {'room_id': roomId},
    };
  }

  if (msg.msgType == 'event') {
    final text = msg.payload['text']?.toString() ?? '';
    roomBroadcaster.broadcastToRoom(
      roomId,
      channel: 'demo/room',
      type: 'event',
      payload: {
        'event': 'room_message',
        'room_id': roomId,
        'user_id': ctx.userId,
        'text': text,
      },
    );
    return {
      'type': 'event',
      'channel': 'demo/room',
      'payload': {
        'event': 'room_message',
        'room_id': roomId,
        'user_id': ctx.userId,
        'text': text,
      },
    };
  }

  return null;
}
