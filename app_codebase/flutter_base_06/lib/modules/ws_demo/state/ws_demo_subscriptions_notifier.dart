import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Room subscriptions per connection — used to re-subscribe after reconnect.
class WsDemoSubscriptionsNotifier extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() => {};

  void subscribeRoom(String connectionId, String roomId) {
    final next = Map<String, Set<String>>.from(state);
    next.putIfAbsent(connectionId, () => {}).add(roomId);
    state = next;
  }

  void unsubscribeRoom(String connectionId, String roomId) {
    final rooms = state[connectionId];
    if (rooms == null) return;
    final next = Map<String, Set<String>>.from(state);
    final updated = Set<String>.from(rooms)..remove(roomId);
    if (updated.isEmpty) {
      next.remove(connectionId);
    } else {
      next[connectionId] = updated;
    }
    state = next;
  }

  void clearConnection(String connectionId) {
    if (!state.containsKey(connectionId)) return;
    final next = Map<String, Set<String>>.from(state)..remove(connectionId);
    state = next;
  }
}

final wsDemoSubscriptionsProvider =
    NotifierProvider<WsDemoSubscriptionsNotifier, Map<String, Set<String>>>(
  WsDemoSubscriptionsNotifier.new,
);
