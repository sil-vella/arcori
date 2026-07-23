import 'contracts/app_state_sink.dart';
import '../ws/app_resume_hooks.dart';

/// Registers tier-1 auth and tier-2 WS infrastructure (Riverpod providers are static).
void registerCoreState(AppStateSink state) {
  resetAppResumeHooks();
}
