import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/dev_logger.dart';
import '../../play/play_models.dart';
import '../practice_ai_pool.dart';
import 'match_replay.dart';
import 'match_snapshot_state.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const stubArenaId = 'arena_velora_plaza';
const stubSlammerId = 'SLM-STR-GEN001-0001';

const Duration practiceStubStepDelayDefault = Duration(milliseconds: 200);

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

  /// Flutter-only practice: human + 2 AI from embedded pool. No Dart WS / API.
  void startLocalPractice({
    required String humanUserId,
    required PracticeLoadout loadout,
    List<String>? aiUserIds,
    Random? random,
  }) {
    final ais = aiUserIds ?? pickPracticeAiUserIds(random: random);
    if (ais.length != 2) {
      throw ArgumentError.value(ais, 'aiUserIds', 'must contain exactly 2 ids');
    }

    final matchId =
        'local_practice_${DateTime.now().microsecondsSinceEpoch}';
    if (LOGGING_SWITCH) {
      customlog(
        'match: startLocalPractice human=$humanUserId '
        'ai=${ais.join(",")} arcori=${loadout.arcoriId}',
      );
    }
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
        MatchSeatView(
          userId: ais[0],
          seatIndex: 1,
          kind: 'ai',
          score: 0,
          connected: true,
          arcoriIds: const [],
          slammerId: '',
        ),
        MatchSeatView(
          userId: ais[1],
          seatIndex: 2,
          kind: 'ai',
          score: 0,
          connected: true,
          arcoriIds: const [],
          slammerId: '',
        ),
      ],
      active: const {'seatIndex': 0, 'action': 'slam'},
    );
  }

  /// Auto-run stub practice: 2 rounds × each seat 1 slam, then end.
  Future<void> runLocalPracticeStubMatch({
    Duration stepDelay = practiceStubStepDelayDefault,
  }) async {
    final matchId = state.matchId;
    if (matchId == null || !state.phaseIsPlaying) return;

    if (LOGGING_SWITCH) {
      customlog(
        'match: stubMatch start matchId=$matchId '
        'rounds=${state.roundsTotal} seats=${state.seats.length}',
      );
    }

    final roundsTotal = state.roundsTotal;
    final seatCount = state.seats.length;
    if (seatCount == 0) return;

    for (var round = 1; round <= roundsTotal; round++) {
      if (!_stillRunning(matchId)) return;

      if (state.round != round) {
        state = state.copyWith(
          round: round,
          active: const {'seatIndex': 0, 'action': 'slam'},
        );
      }

      for (var seatIndex = 0; seatIndex < seatCount; seatIndex++) {
        if (!_stillRunning(matchId)) return;

        final seats = state.seats;
        if (seatIndex >= seats.length) return;
        final actor = seats[seatIndex];

        state = state.copyWith(
          active: {'seatIndex': seatIndex, 'action': 'slam'},
        );
        _applyStubSlam(actorUserId: actor.userId);
        if (LOGGING_SWITCH) {
          customlog(
            'match: stubSlam round=$round seat=$seatIndex '
            'actor=${actor.userId}',
          );
        }
        if (!_stillRunning(matchId)) return;

        if (stepDelay > Duration.zero) {
          await Future<void>.delayed(stepDelay);
        }
      }

      if (round < roundsTotal && _stillRunning(matchId)) {
        state = state.copyWith(
          round: round + 1,
          active: const {'seatIndex': 0, 'action': 'slam'},
        );
      }
    }

    if (_stillRunning(matchId)) {
      localEnd();
      if (LOGGING_SWITCH) {
        customlog('match: stubMatch ended matchId=$matchId');
      }
    }
  }

  bool _stillRunning(String matchId) {
    return state.matchId == matchId && state.phaseIsPlaying;
  }

  /// Stub slam: lastEvent + rotate active. No score/physics.
  void localSlam({required String actorUserId}) {
    _applyStubSlam(actorUserId: actorUserId);
  }

  void _applyStubSlam({required String actorUserId}) {
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
