/// In-memory WebSocket channel registry (mirrors HTTP route registry).
library;

import '../contracts/register_channel_contract.dart';
import '../contracts/ws_message_contract.dart';

const _tierPublic = 'public';
const _tierAuthuser = 'authuser';
const _tierService = 'service';

final ApplicationChannelSink applicationWsSink = _ChannelRegistry._instance;

void resetChannelRegistry() => _ChannelRegistry._instance.clear();

WsChannelHandler? getChannelHandler(String tier, String channel) =>
    _ChannelRegistry._instance.getHandler(tier, channel);

class _ChannelRegistry implements ApplicationChannelSink {
  _ChannelRegistry._();

  static final _ChannelRegistry _instance = _ChannelRegistry._();

  final Map<String, WsChannelHandler> _handlers = {};

  void clear() => _handlers.clear();

  String _key(String tier, String channel) => '$tier:$channel';

  void _add(String tier, String channel, WsChannelHandler handler) {
    _handlers[_key(tier, channel)] = handler;
  }

  WsChannelHandler? getHandler(String tier, String channel) =>
      _handlers[_key(tier, channel)];

  @override
  void publicChannel(String channel, WsChannelHandler handler) =>
      _add(_tierPublic, channel, handler);

  @override
  void authuserChannel(String channel, WsChannelHandler handler) =>
      _add(_tierAuthuser, channel, handler);

  @override
  void serviceChannel(String channel, WsChannelHandler handler) =>
      _add(_tierService, channel, handler);
}
