import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lobby_snapshot_state.dart';

class LobbySnapshotNotifier extends Notifier<LobbySnapshotState> {
  @override
  LobbySnapshotState build() => const LobbySnapshotState();

  void clear() {
    state = const LobbySnapshotState();
  }

  void applyFrame(Map<String, dynamic> data) {
    final payload = data['payload'];
    final map = payload is Map
        ? Map<String, dynamic>.from(payload)
        : Map<String, dynamic>.from(data);
    if (map['lobbyId'] == null || map['lobbyId'].toString().isEmpty) {
      return;
    }
    state = LobbySnapshotState.fromPayload(map);
  }
}

final lobbySnapshotProvider =
    NotifierProvider<LobbySnapshotNotifier, LobbySnapshotState>(
  LobbySnapshotNotifier.new,
);
