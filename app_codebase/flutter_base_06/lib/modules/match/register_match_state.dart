import '../../../core/state/contracts/app_state_sink.dart';
import 'state/match_notifier.dart';
import 'state/match_replay.dart';

void registerMatchState(AppStateSink state) {
  state.onWsReady((registrar, ref) {
    registrar.onPrefix('match', (connectionId, data) {
      ref.read(matchReplayProvider.notifier).store(connectionId, data);
    });
  });
}
