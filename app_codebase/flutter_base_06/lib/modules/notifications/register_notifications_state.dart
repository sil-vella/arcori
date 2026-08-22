import '../../core/state/contracts/app_state_sink.dart';
import '../../core/ws/app_ws_constants.dart';
import '../../utils/dev_logger.dart';
import 'notifications_notifier.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

void registerNotificationsState(AppStateSink state) {
  registerNotificationsResumeHook();

  state.onWsReady((registrar, ref) {
    registrar.onPrefix('notifications', (connectionId, data) {
      if (connectionId != kAppApiWsConnectionId) {
        return;
      }
      final payload = data['payload'];
      final event = payload is Map ? payload['event']?.toString() : null;
      if (LOGGING_SWITCH) {
        customlog(
          'notifications: WS event connectionId=$connectionId '
          'channel=${data['channel']} event=${event ?? '-'}',
        );
      }
      if (event == 'inbox_changed') {
        if (LOGGING_SWITCH) {
          customlog('notifications: inbox_changed → refreshAll');
        }
        ref.read(notificationsProvider.notifier).onInboxChanged(force: true);
      }
    });
  });

  state.onWsReconnect((connectionId, ref, send) async {
    if (connectionId != kAppApiWsConnectionId) {
      return;
    }
    if (LOGGING_SWITCH) {
      customlog('notifications: WS reconnect → refreshAll');
    }
    await ref.read(notificationsProvider.notifier).refreshAll(force: true);
  });
}
