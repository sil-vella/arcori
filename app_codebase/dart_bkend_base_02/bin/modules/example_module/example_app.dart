/// Register example_module WS channels.
library;

import '../../core/ws/contracts/register_channel_contract.dart';
import 'example_ws_service.dart';

void registerExampleModuleWsChannels(ApplicationChannelSink channels) {
  channels.authuserChannel('example/state', handleExampleState);
}
