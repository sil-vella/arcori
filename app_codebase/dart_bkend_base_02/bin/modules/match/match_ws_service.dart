/// Match WS handlers — authuser tier.
library;

import 'dart:async';

import '../../core/errors/app_error.dart';
import '../../core/ws/contracts/ws_message_contract.dart';
import 'match_errors.dart';
import 'match_models.dart';
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

  final rawArcori = msg.payload['arcoriIds'];
  List<String>? arcoriIds;
  if (rawArcori is List) {
    arcoriIds = rawArcori.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  } else {
    final single = msg.payload['arcoriId']?.toString().trim() ?? '';
    if (single.isNotEmpty) arcoriIds = [single];
  }
  final slammerId = msg.payload['slammerId']?.toString().trim();
  final arenaId = msg.payload['arenaId']?.toString().trim();

  final snapshot = await matchService.createPractice(
    callerUserId: userId,
    connectionId: ctx.connectionId,
    callerArcoriIds: arcoriIds,
    callerSlammerId: slammerId,
    arenaId: (arenaId != null && arenaId.isNotEmpty) ? arenaId : stubArenaId,
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

Map<String, dynamic>? handleMatchAction(
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
  final snapshot = matchService.action(
    matchId: matchId,
    userId: userId,
    payload: Map<String, dynamic>.from(msg.payload),
  );
  return {
    'type': 'event',
    'channel': 'match/action',
    'payload': snapshot.toPayload(),
  };
}
