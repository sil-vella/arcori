import '../../core/state/contracts/app_state_sink.dart';
import 'state/ws_demo_log_notifier.dart';
import 'state/ws_demo_subscriptions_notifier.dart';

/// WS demo module state: log handler + room re-subscribe on reconnect.
void registerWsDemoState(AppStateSink state) {
  state.onWsReady((registrar, ref) {
    registrar.onPrefix('demo', (connectionId, data) {
      ref.read(wsDemoLogProvider.notifier).append('$connectionId demo: $data');
    });
  });

  state.onWsReconnect((connectionId, ref, send) async {
    final rooms = ref.read(wsDemoSubscriptionsProvider)[connectionId];
    if (rooms == null || rooms.isEmpty) return;
    for (final roomId in rooms) {
      await send(
        type: 'subscribe',
        channel: 'demo/room',
        payload: {'room_id': roomId},
      );
    }
  });
}
