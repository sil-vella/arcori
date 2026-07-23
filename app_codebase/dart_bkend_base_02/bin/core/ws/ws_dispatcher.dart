/// WebSocket connection loop: auth handshake, channel routing, JSON envelopes.
library;

import 'dart:async';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/verify_access.dart';
import '../auth/verify_service_key.dart';
import '../errors/app_error.dart';
import '../errors/error_codes.dart';
import '../state/room/room_lifecycle.dart';
import '../state/state_registry.dart';
import 'contracts/ws_message_contract.dart';
import 'response/ws_response.dart';
import 'service/channel_registry.dart';
import '../../modules/ops/ops_errors.dart';
import '../../modules/ops/ops_state.dart';
import '../../utils/dev_logger.dart';

const _tierPublic = 'public';
const _tierAuthuser = 'authuser';
const _tierService = 'service';

const bool LOGGING_SWITCH = false; // ignore: constant_identifier_names

final _connectionCounter = _ConnectionIdGenerator();

Future<void> runWsConnection(WebSocketChannel channel, {required String tier}) async {
  final connectionId = _connectionCounter.next();
  final ctx = WsConnectionContext(tier: tier, connectionId: connectionId);
  final needsAuth = tier == _tierAuthuser || tier == _tierService;

  void registerConnection() {
    connectionRegistry.register(
      connectionId,
      (frame) => channel.sink.add(frame),
    );
  }

  void unregisterConnection() {
    connectionRegistry.unregister(connectionId);
  }

  if (drainMode) {
    if (LOGGING_SWITCH) {
      customlog('ws rejected drain_mode tier=$tier connectionId=$connectionId');
    }
    channel.sink.add(AppError(serverMaintenance).toWsFrame());
    await channel.sink.close();
    return;
  }

  if (tier == _tierPublic) {
    ctx.authenticated = true;
    registerConnection();
    if (LOGGING_SWITCH) {
      customlog('ws connected tier=$tier connectionId=$connectionId');
    }
    channel.sink.add(encodeWsOk({'type': 'connected', 'channel': 'system'}));
  }

  try {
    await for (final message in channel.stream) {
      final text = message is String ? message : message.toString();
      final parsed = parseIncoming(text);
      if (parsed.error != null) {
        if (LOGGING_SWITCH) {
          customlog(
            'ws parse error tier=$tier connectionId=$connectionId '
            'code=${parsed.error!['code']}',
          );
        }
        channel.sink.add(
          encodeWsError(
            code: parsed.error!['code']!,
            message: parsed.error!['message']!,
          ),
        );
        continue;
      }

      final data = parsed.data!;
      final msg = WsClientMessage.fromData(data);
      if (msg == null) {
        channel.sink.add(
          encodeWsError(
            code: invalidMessage.code,
            message: 'type and channel required',
          ),
        );
        continue;
      }

      if (needsAuth && !ctx.authenticated) {
        if (msg.msgType != 'auth') {
          final err = AppError(unauthorized, message: 'First message must be type auth');
          channel.sink.add(err.toWsFrame());
          await channel.sink.close();
          return;
        }
        final authResult = tier == _tierAuthuser
            ? _handleAuthuserAuth(ctx, data)
            : _handleServiceAuth(ctx, data);
        channel.sink.add(authResult.frame);
        if (!authResult.ok) {
          if (LOGGING_SWITCH) {
            customlog('ws auth failed tier=$tier connectionId=$connectionId');
          }
          await channel.sink.close();
          return;
        }
        registerConnection();
        if (LOGGING_SWITCH) {
          customlog(
            'ws authenticated tier=$tier connectionId=$connectionId '
            'userId=${ctx.userId ?? ''}',
          );
        }
        continue;
      }

      final handler = getChannelHandler(tier, msg.channel);
      if (handler == null) {
        final err = AppError(notFound, message: 'No handler for channel ${msg.channel}');
        channel.sink.add(err.toWsFrame());
        continue;
      }

      try {
        final result = handler(ctx, msg);
        if (result != null) {
          channel.sink.add(encodeWsOk(result));
        }
      } on AppError catch (err) {
        channel.sink.add(err.toWsFrame());
        if (err.spec.fatalWs) {
          await channel.sink.close();
          return;
        }
      } catch (_) {
        if (LOGGING_SWITCH) {
          customlog(
            'ws handler error tier=$tier channel=${msg.channel} '
            'connectionId=$connectionId',
          );
        }
        channel.sink.add(AppError(internalError, message: 'Handler failed').toWsFrame());
      }
    }
  } finally {
    if (LOGGING_SWITCH) {
      customlog('ws closed tier=$tier connectionId=$connectionId');
    }
    onWsConnectionClosed(connectionId);
    unregisterConnection();
  }
}

class _AuthResult {
  _AuthResult({required this.ok, required this.frame});
  final bool ok;
  final String frame;
}

_AuthResult _handleAuthuserAuth(
  WsConnectionContext ctx,
  Map<String, dynamic> data,
) {
  final payload = data['payload'];
  final map = payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
  final token = map['access_token']?.toString().trim() ?? '';
  try {
    final authCtx = verifyAccessOrThrow(token.isEmpty ? null : token);
    ctx.userId = authCtx.userId;
    ctx.claims = authCtx.claims;
    ctx.authenticated = true;
    return _AuthResult(
      ok: true,
      frame: encodeWsOk({
        'type': 'connected',
        'channel': 'system',
        'user_id': ctx.userId,
      }),
    );
  } on AppError catch (err) {
    return _AuthResult(ok: false, frame: err.toWsFrame());
  }
}

_AuthResult _handleServiceAuth(
  WsConnectionContext ctx,
  Map<String, dynamic> data,
) {
  final payload = data['payload'];
  final map = payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
  final provided = map['service_key']?.toString() ?? '';
  try {
    verifyServiceKeyOrThrow(provided.isEmpty ? null : provided);
    ctx.authenticated = true;
    return _AuthResult(
      ok: true,
      frame: encodeWsOk({'type': 'connected', 'channel': 'system'}),
    );
  } on AppError catch (err) {
    return _AuthResult(ok: false, frame: err.toWsFrame());
  }
}

class _ConnectionIdGenerator {
  int _seq = 0;

  String next() {
    _seq += 1;
    return 'conn-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}-$_seq';
  }
}
