/// Register match WS channels.
library;

import '../../core/ws/contracts/register_channel_contract.dart';
import 'match_ws_service.dart';

void registerMatchWsChannels(ApplicationChannelSink channels) {
  channels.authuserChannel('match/create', handleMatchCreate);
  channels.authuserChannel('match/join', handleMatchJoin);
  channels.authuserChannel('match/leave', handleMatchLeave);
  channels.authuserChannel('match/end', handleMatchEnd);
}
