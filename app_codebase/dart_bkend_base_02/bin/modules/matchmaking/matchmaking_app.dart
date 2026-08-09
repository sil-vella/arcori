/// Register matchmaking WS channels.
library;

import '../../core/ws/contracts/register_channel_contract.dart';
import 'matchmaking_ws_service.dart';

void registerMatchmakingWsChannels(ApplicationChannelSink channels) {
  channels.authuserChannel('matchmaking/find', handleMatchmakingFind);
  channels.authuserChannel('matchmaking/cancel', handleMatchmakingCancel);
}
