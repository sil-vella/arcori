import '../../../core/state/contracts/app_state_sink.dart';
import 'state/example_module_notifier.dart';
import 'state/example_module_replay.dart';

void registerExampleModuleState(AppStateSink state) {
  state.onWsReady((registrar, ref) {
    registrar.onPrefix('example', (connectionId, data) {
      ref.read(exampleModuleReplayProvider.notifier).store(connectionId, data);
    });
  });
}
