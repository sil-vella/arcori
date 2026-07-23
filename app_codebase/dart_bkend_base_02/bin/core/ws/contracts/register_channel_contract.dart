/// Let feature modules register WebSocket channel handlers without knowing the registry.
library;

import 'ws_message_contract.dart';

abstract interface class ApplicationChannelSink {
  void publicChannel(String channel, WsChannelHandler handler);
  void authuserChannel(String channel, WsChannelHandler handler);
  void serviceChannel(String channel, WsChannelHandler handler);
}
