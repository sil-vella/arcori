/// Match WS handlers — authuser tier.
library;

import 'dart:async';

import '../../core/errors/app_error.dart';
import '../../core/ws/contracts/ws_message_contract.dart';
import 'match_errors.dart';
import 'match_service.dart';

FutureOr<Map<String, dynamic>?> handleMatchCreate(
  WsConnectionContext ctx,
  WsClientMessage msg,
) async {
  if (msg.msgType != 'event') {
    return null;
  }
  final userId = ctx.userId;
  if (userId == null || userId.isEmpty) {
    throw AppError(matchUnauthorized);
  }
  final snapshot = await matchService.createPractice(
    callerUserId: userId,
    connectionId: ctx.connectionId,
  );
  return {
    'type': 'event',
    'channel': 'match/create',
    'payload': snapshot.toPayload(),
  };
}

Map<String, dynamic>? handleMatchJoin(
  WsConnectionContext ctx,
  WsClientMessage msg,
) {
  if (msg.msgType != 'event') {
    return null;
  }
  final userId = ctx.userId;
  if (userId == null || userId.isEmpty) {
    throw AppError(matchUnauthorized);
  }
  final matchId = msg.payload['matchId']?.toString().trim() ?? '';
  if (matchId.isEmpty) {
    throw AppError(matchInvalidRequest, message: 'matchId required');
  }
  final snapshot = matchService.join(
    matchId: matchId,
    userId: userId,
    connectionId: ctx.connectionId,
  );
  return {
    'type': 'event',
    'channel': 'match/join',
    'payload': snapshot.toPayload(),
  };
}

Map<String, dynamic>? handleMatchLeave(
  WsConnectionContext ctx,
  WsClientMessage msg,
) {
  if (msg.msgType != 'event') {
    return null;
  }
  final userId = ctx.userId;
  if (userId == null || userId.isEmpty) {
    throw AppError(matchUnauthorized);
  }
  final matchId = msg.payload['matchId']?.toString().trim() ?? '';
  if (matchId.isEmpty) {
    throw AppError(matchInvalidRequest, message: 'matchId required');
  }
  final snapshot = matchService.leave(
    matchId: matchId,
    userId: userId,
    connectionId: ctx.connectionId,
  );
  return {
    'type': 'event',
    'channel': 'match/leave',
    'payload': snapshot.toPayload(),
  };
}

Map<String, dynamic>? handleMatchEnd(
  WsConnectionContext ctx,
  WsClientMessage msg,
) {
  if (msg.msgType != 'event') {
    return null;
  }
  final userId = ctx.userId;
  if (userId == null || userId.isEmpty) {
    throw AppError(matchUnauthorized);
  }
  final matchId = msg.payload['matchId']?.toString().trim() ?? '';
  if (matchId.isEmpty) {
    throw AppError(matchInvalidRequest, message: 'matchId required');
  }
  final snapshot = matchService.end(matchId: matchId, userId: userId);
  return {
    'type': 'event',
    'channel': 'match/end',
    'payload': snapshot.toPayload(),
  };
}
