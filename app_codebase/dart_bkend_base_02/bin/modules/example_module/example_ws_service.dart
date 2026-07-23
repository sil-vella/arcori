/// Example module WS handler — authuser tier, single-client demo.
library;

import '../../core/errors/app_error.dart';
import '../../core/ws/contracts/ws_message_contract.dart';
import 'example_errors.dart';
import 'example_service.dart';

Map<String, dynamic>? handleExampleState(
  WsConnectionContext ctx,
  WsClientMessage msg,
) {
  if (msg.msgType != 'event') {
    return null;
  }
  final userId = ctx.userId;
  if (userId == null || userId.isEmpty) {
    throw AppError(exampleUnauthorized);
  }
  final record = msg.payload['record'] == true;
  final snapshot = exampleModuleService.applyEvent(
    userId: userId,
    patch: Map<String, dynamic>.from(msg.payload),
    record: record,
  );
  return {
    'type': 'event',
    'channel': 'example/state',
    'payload': snapshot.toPayload(),
  };
}
