/// Matchmaking WS handlers — authuser tier.
library;

import 'dart:async';

import '../../core/errors/app_error.dart';
import '../../core/ws/contracts/ws_message_contract.dart';
import 'matchmaking_errors.dart';
import 'matchmaking_service.dart';

FutureOr<Map<String, dynamic>?> handleMatchmakingFind(
  WsConnectionContext ctx,
  WsClientMessage msg,
) async {
  if (msg.msgType != 'event') {
    return null;
  }
  final userId = ctx.userId;
  if (userId == null || userId.isEmpty) {
    throw AppError(matchmakingUnauthorized);
  }
  final lobby = await matchmakingService.find(
    userId: userId,
    connectionId: ctx.connectionId,
    payload: Map<String, dynamic>.from(msg.payload),
  );
  return {
    'type': 'event',
    'channel': 'matchmaking/find',
    'payload': lobby.toPayload(),
  };
}

Map<String, dynamic>? handleMatchmakingCancel(
  WsConnectionContext ctx,
  WsClientMessage msg,
) {
  if (msg.msgType != 'event') {
    return null;
  }
  final userId = ctx.userId;
  if (userId == null || userId.isEmpty) {
    throw AppError(matchmakingUnauthorized);
  }
  final lobby = matchmakingService.cancel(
    userId: userId,
    connectionId: ctx.connectionId,
  );
  return {
    'type': 'event',
    'channel': 'matchmaking/cancel',
    'payload': lobby.toPayload(),
  };
}
