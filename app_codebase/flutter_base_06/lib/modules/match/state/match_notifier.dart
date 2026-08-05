import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'match_replay.dart';
import 'match_snapshot_state.dart';

class MatchSnapshotNotifier extends Notifier<MatchSnapshotState> {
  @override
  MatchSnapshotState build() {
    ref.listen<MatchPending?>(matchReplayProvider, (_, next) {
      if (next != null) {
        applyWsFrame(next.data);
        Future.microtask(ref.read(matchReplayProvider.notifier).take);
      }
    });

    final pending = ref.read(matchReplayProvider);
    if (pending != null) {
      Future.microtask(ref.read(matchReplayProvider.notifier).take);
      return _applyFrame(const MatchSnapshotState(), pending.data);
    }
    return const MatchSnapshotState();
  }

  void clear() {
    state = const MatchSnapshotState();
  }

  void applyWsFrame(Map<String, dynamic> data) {
    state = _applyFrame(state, data);
  }

  MatchSnapshotState _applyFrame(
    MatchSnapshotState current,
    Map<String, dynamic> data,
  ) {
    final payload = data['payload'];
    final map = payload is Map
        ? Map<String, dynamic>.from(payload)
        : Map<String, dynamic>.from(data);
    final next = MatchSnapshotState.fromPayload(map);
    if (next.matchId == null || next.matchId!.isEmpty) {
      return current;
    }
    // Ignore older versions for the same match.
    if (current.matchId == next.matchId && next.version < current.version) {
      return current;
    }
    return next;
  }
}

final matchSnapshotProvider =
    NotifierProvider<MatchSnapshotNotifier, MatchSnapshotState>(
  MatchSnapshotNotifier.new,
);
