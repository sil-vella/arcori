import '../../core/state/contracts/app_state_sink.dart';
import '../../core/ws/app_ws_constants.dart';
import 'notifications_notifier.dart';

void registerNotificationsState(AppStateSink state) {
  registerNotificationsResumeHook();

  state.onWsReady((registrar, ref) {
    registrar.onPrefix('notifications', (connectionId, data) {
      if (connectionId != kAppApiWsConnectionId) {
        return;
      }
      final payload = data['payload'];
      final event = payload is Map ? payload['event']?.toString() : null;
      if (event == 'inbox_changed') {
        ref.read(notificationsProvider.notifier).onInboxChanged(force: true);
      }
    });
  });

  state.onWsReconnect((connectionId, ref, send) async {
    if (connectionId != kAppApiWsConnectionId) {
      return;
    }
    await ref.read(notificationsProvider.notifier).refreshAll(force: true);
  });
}
