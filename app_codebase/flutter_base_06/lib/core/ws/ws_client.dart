import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../errors/api_error.dart';
import 'contracts/ws_client_contract.dart';
import 'ws_message.dart';

/// Connect, auth handshake, send/receive JSON WebSocket frames.
class WsClient implements WsClientContract {
  WsClient();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionClosed = StreamController<void>.broadcast();
  bool _intentionalClose = false;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Stream<void> get connectionClosed => _connectionClosed.stream;

  @override
  bool get isConnected => _channel != null;

  @override
  Future<void> connect({
    required String url,
    String? accessToken,
    String? serviceKey,
  }) async {
    await disconnect();
    _intentionalClose = false;
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _subscription = _channel!.stream.listen(
      (event) {
        try {
          final msg = WsMessage.parse(event.toString());
          if (msg.ok && msg.data != null) {
            _messages.add(msg.data!);
          } else {
            _messages.addError(
              ApiError(
                code: ApiErrorCode.parse(msg.errorCode ?? 'internal_error'),
                message: msg.errorMessage ?? 'WebSocket error',
                rawCode: msg.errorCode ?? 'internal_error',
              ),
            );
          }
        } catch (e) {
          _messages.addError(e);
        }
      },
      onError: _messages.addError,
      onDone: () async {
        final intentional = _intentionalClose;
        await _tearDownChannel();
        if (!intentional && !_connectionClosed.isClosed) {
          _connectionClosed.add(null);
        }
      },
    );

    if (accessToken != null && accessToken.isNotEmpty) {
      await send(
        type: 'auth',
        channel: 'system',
        payload: {'access_token': accessToken},
      );
    } else if (serviceKey != null && serviceKey.isNotEmpty) {
      await send(
        type: 'auth',
        channel: 'system',
        payload: {'service_key': serviceKey},
      );
    }
  }

  @override
  Future<void> send({
    required String type,
    required String channel,
    Map<String, dynamic>? payload,
  }) async {
    final channel_ = _channel;
    if (channel_ == null) {
      throw StateError('Not connected');
    }
    channel_.sink.add(
      WsMessage.encodeClient(
        type: type,
        channel: channel,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _intentionalClose = true;
    await _tearDownChannel();
  }

  Future<void> _tearDownChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await channel.sink.close();
    }
  }
}

/// Back-compat alias — prefer [ApiError] for new code.
typedef WsClientException = ApiError;
