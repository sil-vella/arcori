import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/dev_logger.dart';
import 'lobby_snapshot_state.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class LobbySnapshotNotifier extends Notifier<LobbySnapshotState> {
  @override
  LobbySnapshotState build() => const LobbySnapshotState();

  void clear() {
    if (LOGGING_SWITCH) {
      customlog('LobbySnapshotNotifier: clear');
    }
    state = const LobbySnapshotState();
  }

  void applyFrame(Map<String, dynamic> data) {
    final payload = data['payload'];
    final map = payload is Map
        ? Map<String, dynamic>.from(payload)
        : Map<String, dynamic>.from(data);
    if (map['lobbyId'] == null || map['lobbyId'].toString().isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('LobbySnapshotNotifier: skip frame (no lobbyId)');
      }
      return;
    }
    final next = LobbySnapshotState.fromPayload(map);
    if (LOGGING_SWITCH) {
      customlog(
        'LobbySnapshotNotifier: apply lobbyId=${next.lobbyId} '
        'phase=${next.phase} members=${next.members.length}/'
        '${next.targetSeats} matchId=${next.matchId}',
      );
    }
    state = next;
  }
}

final lobbySnapshotProvider =
    NotifierProvider<LobbySnapshotNotifier, LobbySnapshotState>(
  LobbySnapshotNotifier.new,
);
