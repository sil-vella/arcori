import '../../../core/ws/ws_connection_manager.dart';

const _dartWsId = 'dart';

/// Send a match gameplay action over Dart authuser WS.
Future<void> sendMatchAction({
  required WsConnectionManager manager,
  required String matchId,
  required String action,
  Map<String, dynamic>? input,
}) async {
  await manager.send(
    _dartWsId,
    type: 'event',
    channel: 'match/action',
    payload: {
      'matchId': matchId,
      'action': action,
      if (input != null) 'input': input,
    },
  );
}
