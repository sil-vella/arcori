import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../play/play_models.dart';
import 'match_replay.dart';
import 'match_snapshot_state.dart';

const stubArenaId = 'arena_velora_plaza';
const stubAiArcoriId = 'ANM-WTI-GEN001-0002';
const stubAiArcoriId2 = 'ANM-TIG-GEN001-0001';
const stubSlammerId = 'SLM-STR-GEN001-0001';

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

  /// Flutter-only practice: human + 2 AI. No Dart WS.
  void startLocalPractice({
    required String humanUserId,
    required PracticeLoadout loadout,
  }) {
    final matchId =
        'local_practice_${DateTime.now().microsecondsSinceEpoch}';
    state = MatchSnapshotState(
      matchId: matchId,
      version: 1,
      phase: 'playing',
      round: 1,
      roundsTotal: 2,
      arenaId: stubArenaId,
      callerUserId: humanUserId,
      matchType: const {'code': 'practice'},
      seats: [
        MatchSeatView(
          userId: humanUserId,
          seatIndex: 0,
          kind: 'human',
          score: 0,
          connected: true,
          arcoriIds: [loadout.arcoriId],
          slammerId: loadout.slammerId,
        ),
        const MatchSeatView(
          userId: 'ai:seat_1',
          seatIndex: 1,
          kind: 'ai',
          score: 0,
          connected: true,
          arcoriIds: [stubAiArcoriId],
          slammerId: stubSlammerId,
        ),
        const MatchSeatView(
          userId: 'ai:seat_2',
          seatIndex: 2,
          kind: 'ai',
          score: 0,
          connected: true,
          arcoriIds: [stubAiArcoriId2],
          slammerId: stubSlammerId,
        ),
      ],
      active: const {'seatIndex': 0, 'action': 'slam'},
    );
  }

  /// Stub slam: lastEvent + rotate active. No score/physics.
  void localSlam({required String actorUserId}) {
    final current = state;
    if (!current.phaseIsPlaying || current.matchId == null) return;

    MatchSeatView? actor;
    for (final s in current.seats) {
      if (s.userId == actorUserId) {
        actor = s;
        break;
      }
    }
    if (actor == null) return;

    final activeSeat = current.active?['seatIndex'];
    if (activeSeat is int && activeSeat != actor.seatIndex) return;

    final nextSeat = (actor.seatIndex + 1) % current.seats.length;
    final nextVersion = current.version + 1;
    state = current.copyWith(
      version: nextVersion,
      active: {'seatIndex': nextSeat, 'action': 'slam'},
      lastEvent: {
        'type': 'slam',
        'actorUserId': actorUserId,
        'result': 'stub',
        'version': nextVersion,
      },
    );
  }

  void localEnd() {
    final current = state;
    if (current.matchId == null || current.isEnded) return;

    final scores = <String, int>{
      for (final s in current.seats) s.userId: s.score,
    };
    final winners = current.seats
        .where((s) => s.kind == 'human')
        .map((s) => s.userId)
        .toList();
    final nextVersion = current.version + 1;
    state = current.copyWith(
      version: nextVersion,
      phase: 'ended',
      clearActive: true,
      lastEvent: {
        'type': 'match_ended',
        'actorUserId': null,
        'result': 'completed',
        'version': nextVersion,
      },
      result: {
        'winnerUserIds': winners,
        'finalScores': scores,
      },
    );
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
    if (current.matchId == next.matchId && next.version < current.version) {
      return current;
    }
    return next;
  }
}

extension on MatchSnapshotState {
  bool get phaseIsPlaying => phase == 'playing';
}

final matchSnapshotProvider =
    NotifierProvider<MatchSnapshotNotifier, MatchSnapshotState>(
  MatchSnapshotNotifier.new,
);
