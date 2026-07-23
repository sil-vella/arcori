/// Register demo WebSocket channels on all tiers.
library;

import '../../core/ws/contracts/register_channel_contract.dart';
import 'demo_ws_service.dart';

void registerDemoWsChannels(ApplicationChannelSink channels) {
  for (final register in [
    channels.publicChannel,
    channels.authuserChannel,
    channels.serviceChannel,
  ]) {
    register('system', handleSystem);
    register('demo/echo', handleDemoEcho);
    register('demo/room', handleDemoRoom);
  }
}
