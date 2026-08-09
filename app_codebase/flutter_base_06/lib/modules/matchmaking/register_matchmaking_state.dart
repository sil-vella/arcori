import '../../../core/state/contracts/app_state_sink.dart';
import 'state/lobby_notifier.dart';

void registerMatchmakingState(AppStateSink state) {
  state.onWsReady((registrar, ref) {
    registrar.onPrefix('matchmaking', (connectionId, data) {
      ref.read(lobbySnapshotProvider.notifier).applyFrame(data);
    });
  });
}
