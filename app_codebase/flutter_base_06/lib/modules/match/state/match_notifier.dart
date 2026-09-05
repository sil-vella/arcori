import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/dev_logger.dart';
import '../../play/play_models.dart';
import '../input/match_grace.dart';
import '../input/slam_input_models.dart';
import '../input/slam_resolver.dart';
import '../input/turn_order.dart';
import '../input/turn_pacing.dart';
import '../practice_ai_pool.dart';
import 'match_replay.dart';
import 'match_snapshot_state.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const stubArenaId = 'arena_velora_plaza';
const stubSlammerId = 'SLM-STR-GEN001-0001';

class MatchSnapshotNotifier extends Notifier<MatchSnapshotState> {
  Completer<void>? _humanTurnWait;

  /// Tunable for tests — default 5s grace + 5s human turn window.
  Duration practiceMatchStartGrace = matchStartGraceDefault;
  Duration practiceTurnTimeout = turnTimeoutDefault;
  Duration practiceAiDelayMin = aiDelayMinDefault;
  Duration practiceAiDelayMax = aiDelayMaxDefault;
  double practiceAiMissProbability = aiMissProbabilityDefault;

  /// TEST: pause after each slam before the next seat's turn.
  Duration practicePostSlamAnimHold = postSlamAnimHoldDefault;
  Random? practiceTurnRandom;

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
    _humanTurnWait = null;
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
    int? firstSeatIndex,
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
    final seats = [
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
        arcoriIds: const [stubPracticeAiArcoriId],
        slammerId: stubSlammerId,
      ),
      MatchSeatView(
        userId: ais[1],
        seatIndex: 2,
        kind: 'ai',
        score: 0,
        connected: true,
        arcoriIds: const [stubPracticeAiArcoriId],
        slammerId: stubSlammerId,
      ),
    ];
    final rng = random ?? practiceTurnRandom ?? Random();
    final first = firstSeatIndex ??
        (seats.length <= 1 ? 0 : rng.nextInt(seats.length));
    if (LOGGING_SWITCH) {
      customlog('match: startLocalPractice firstSeat=$first');
    }
    final faces = <String, Map<String, String?>>{
      for (final e in practiceFaceDefaults.entries)
        e.key: Map<String, String?>.from(e.value),
    };
    final loadoutUrl = loadout.arcoriImageUrl?.trim() ?? '';
    final loadoutColor = loadout.arcoriColor?.trim() ?? '';
    if (loadoutUrl.isNotEmpty || loadoutColor.isNotEmpty) {
      faces[loadout.arcoriId] = {
        'imageUrl': loadoutUrl.isNotEmpty
            ? loadoutUrl
            : faces[loadout.arcoriId]?['imageUrl'],
        'color': loadoutColor.isNotEmpty
            ? loadoutColor
            : faces[loadout.arcoriId]?['color'],
      };
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
      seats: seats,
      firstSeatIndex: first,
      table: tableFromSeatViews(
        seats: [
          for (final s in seats)
            (
              userId: s.userId,
              seatIndex: s.seatIndex,
              arcoriIds: s.arcoriIds,
            ),
        ],
        facesByDesignId: faces,
      ),
      active: practiceMatchStartGrace <= Duration.zero
          ? <String, dynamic>{'seatIndex': first, 'action': 'slam'}
          : activeWithGrace(
              practiceMatchStartGrace,
              seatIndex: first,
            ),
    );
  }

  /// Turn-based practice: human gesture window + paced AI slams, then end.
  Future<void> runLocalPracticeTurnMatch() async {
    final matchId = state.matchId;
    if (matchId == null || !state.phaseIsPlaying) return;

    final rng = practiceTurnRandom ?? Random();
    final roundsTotal = state.roundsTotal;
    final seatCount = state.seats.length;
    if (seatCount == 0) return;

    if (LOGGING_SWITCH) {
      customlog(
        'match: practiceTurn start matchId=$matchId '
        'rounds=$roundsTotal seats=$seatCount '
        'firstSeat=${state.firstSeatIndex} '
        'grace=${practiceMatchStartGrace.inSeconds}s',
      );
    }

    await _waitPracticeGrace(matchId);

    final first = state.firstSeatIndex;
    for (var round = 1; round <= roundsTotal; round++) {
      if (!_stillRunning(matchId)) return;

      final order = seatOrderForRound(
        seatCount: seatCount,
        firstSeatIndex: first,
      );
      for (final seatIndex in order) {
        if (!_stillRunning(matchId)) return;

        if (_activeSeatIndex(state) != seatIndex) {
          state = state.copyWith(
            round: round,
            active: {'seatIndex': seatIndex, 'action': 'slam'},
          );
        }

        final actor = state.seats[seatIndex];
        if (actor.kind == 'human') {
          await _waitHumanPracticeTurn(
            matchId: matchId,
            seatIndex: seatIndex,
            actorUserId: actor.userId,
          );
        } else {
          await _runAiPracticeTurn(
            matchId: matchId,
            seatIndex: seatIndex,
            actorUserId: actor.userId,
            rng: rng,
          );
        }
        await _holdPracticeForAnim(matchId, seatIndex);
      }
    }

    if (_stillRunning(matchId)) {
      localEnd();
      if (LOGGING_SWITCH) {
        customlog('match: practiceTurn ended matchId=$matchId');
      }
    }
  }

  Future<void> runLocalPracticeStubMatch({Duration stepDelay = Duration.zero}) async {
    if (stepDelay <= Duration.zero) {
      practiceMatchStartGrace = Duration.zero;
      practiceTurnTimeout = Duration.zero;
      practiceAiDelayMin = Duration.zero;
      practiceAiDelayMax = Duration.zero;
      practiceAiMissProbability = 0;
      practicePostSlamAnimHold = Duration.zero;
    }
    await runLocalPracticeTurnMatch();
  }

  Future<void> _waitPracticeGrace(String matchId) async {
    if (practiceMatchStartGrace <= Duration.zero) {
      _clearPracticeGrace();
      return;
    }

    final deadline = DateTime.now().add(practiceMatchStartGrace);
    while (DateTime.now().isBefore(deadline)) {
      if (!_stillRunning(matchId)) return;
      final remaining = deadline.difference(DateTime.now());
      await Future<void>.delayed(
        remaining < turnPollInterval ? remaining : turnPollInterval,
      );
    }
    if (!_stillRunning(matchId)) return;
    _clearPracticeGrace();
    if (LOGGING_SWITCH) {
      customlog('match: practiceTurn grace ended matchId=$matchId');
    }
  }

  void _clearPracticeGrace() {
    if (!activeInGracePeriod(state.active)) return;
    state = state.copyWith(active: activeWithoutGrace(state.active));
  }

  Future<void> _waitHumanPracticeTurn({
    required String matchId,
    required int seatIndex,
    required String actorUserId,
  }) async {
    if (practiceTurnTimeout <= Duration.zero) {
      if (_activeSeatIndex(state) == seatIndex) {
        _applyStubSlam(
          actorUserId: actorUserId,
          input: timeoutSlamInputMap(),
        );
      }
      return;
    }

    _humanTurnWait = Completer<void>();
    try {
      await _humanTurnWait!.future.timeout(practiceTurnTimeout);
    } on TimeoutException {
      if (LOGGING_SWITCH) {
        customlog(
          'match: practiceTurn human timeout seat=$seatIndex user=$actorUserId',
        );
      }
    } finally {
      _humanTurnWait = null;
    }

    if (!_stillRunning(matchId)) return;
    if (_activeSeatIndex(state) == seatIndex) {
      _applyStubSlam(
        actorUserId: actorUserId,
        input: timeoutSlamInputMap(),
      );
    }
  }

  Future<void> _runAiPracticeTurn({
    required String matchId,
    required int seatIndex,
    required String actorUserId,
    required Random rng,
  }) async {
    final miss = rollAiMiss(rng, probability: practiceAiMissProbability);
    if (miss) {
      if (LOGGING_SWITCH) {
        customlog('match: practiceTurn ai miss seat=$seatIndex');
      }
      await _waitHumanPracticeTurn(
        matchId: matchId,
        seatIndex: seatIndex,
        actorUserId: actorUserId,
      );
      if (!_stillRunning(matchId)) return;
      if (_activeSeatIndex(state) == seatIndex) {
        _applyStubSlam(
          actorUserId: actorUserId,
          input: timeoutSlamInputMap(source: 'ai_timeout'),
        );
      }
      return;
    }

    final delay = randomAiDelay(
      rng,
      min: practiceAiDelayMin,
      max: practiceAiDelayMax,
    );
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!_stillRunning(matchId)) return;
    if (_activeSeatIndex(state) != seatIndex) return;

    _applyStubSlam(
      actorUserId: actorUserId,
      input: syntheticAiSlamInput(rng),
    );
    if (LOGGING_SWITCH) {
      customlog('match: practiceTurn ai slam seat=$seatIndex user=$actorUserId');
    }
  }

  /// Hold after slam: prefer last outcome.sim.animHoldMs (steps×dt + settle).
  Future<void> _holdPracticeForAnim(String matchId, int seatIndex) async {
    if (practicePostSlamAnimHold <= Duration.zero) {
      _clearPracticeAnimLock();
      return;
    }
    if (!_stillRunning(matchId)) return;
    final fromSim = animHoldFromLastEvent(state.lastEvent);
    final hold = fromSim ?? practicePostSlamAnimHold;
    if (LOGGING_SWITCH) {
      customlog(
        'match: practiceTurn postSlamAnimHold afterSeat=$seatIndex '
        'ms=${hold.inMilliseconds}'
        '${fromSim != null ? ' source=simSteps' : ' source=default'}',
      );
    }
    await Future<void>.delayed(hold);
    if (!_stillRunning(matchId)) return;
    _clearPracticeAnimLock();
  }

  void _clearPracticeAnimLock() {
    final active = state.active;
    if (active == null || !active.containsKey('inputLockedUntil')) return;
    state = state.copyWith(
      version: state.version + 1,
      active: activeWithoutAnimLock(active),
    );
    if (LOGGING_SWITCH) {
      customlog(
        'match: practiceTurn clearAnimLock seat=${state.active?['seatIndex']}',
      );
    }
  }

  bool _stillRunning(String matchId) {
    return state.matchId == matchId && state.phaseIsPlaying;
  }

  int? _activeSeatIndex(MatchSnapshotState snap) {
    final active = snap.active?['seatIndex'];
    return active is int ? active : null;
  }

  /// Slam: resolve flips, rotate active, restack on round advance.
  void localSlam({
    required String actorUserId,
    Map<String, dynamic>? input,
  }) {
    _applyStubSlam(actorUserId: actorUserId, input: input);
    final wait = _humanTurnWait;
    if (wait != null && !wait.isCompleted) {
      wait.complete();
    }
  }

  void _applyStubSlam({
    required String actorUserId,
    Map<String, dynamic>? input,
  }) {
    final current = state;
    if (!current.phaseIsPlaying || current.matchId == null) return;

    if (activeInGracePeriod(current.active)) return;
    if (activeInputLocked(current.active)) return;

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

    final seatCount = current.seats.length;
    final advanced = advanceTurnActive(
      actorSeatIndex: actor.seatIndex,
      seatCount: seatCount,
      firstSeatIndex: current.firstSeatIndex,
      round: current.round,
      roundsTotal: current.roundsTotal,
    );
    final nextRound = advanced.round;

    final slamInput = input ?? timeoutSlamInputMap();
    final attrs = practiceSlammerAttrs[actor.slammerId] ??
        defaultGameplayAttributes.map((k, v) => MapEntry(k, v));

    final resolved = resolveSlam(
      matchId: current.matchId!,
      version: current.version,
      actorSeatIndex: actor.seatIndex,
      input: slamInput,
      gameplayAttributes: Map<String, dynamic>.from(attrs),
      table: current.table,
    );

    if (LOGGING_SWITCH) {
      final frames = resolved.sim?['frames'];
      final frameCount = frames is List ? frames.length : 0;
      customlog(
        'match: practice slam result=${resolved.result} '
        'flips=${resolved.flippedPieceIds.length} '
        'power=${resolved.impulse['power']} simFrames=$frameCount '
        'flippedIds=${resolved.flippedPieceIds}',
      );
    }

    final holdMs = resolved.sim?['animHoldMs'] is num
        ? (resolved.sim!['animHoldMs'] as num).round()
        : practicePostSlamAnimHold.inMilliseconds;
    final nextActive = activeWithAnimLock(
      advanced.active,
      Duration(milliseconds: holdMs),
    );

    final scoreByUser = <String, int>{
      for (final s in current.seats) s.userId: s.score,
    };
    for (final e in resolved.scoreDeltas.entries) {
      scoreByUser[e.key] = (scoreByUser[e.key] ?? 0) + e.value;
    }
    final nextSeats = current.seats
        .map((s) => s.copyWith(score: scoreByUser[s.userId] ?? s.score))
        .toList();

    // Always restack face-down after a slam so the next seat starts clean.
    final nextTable = restackFaceDown({'pieces': resolved.pieces});

    final nextVersion = current.version + 1;
    final arcoriId =
        actor.arcoriIds.isNotEmpty ? actor.arcoriIds.first : null;
    final lastEvent = <String, dynamic>{
      'type': 'slam',
      'actorUserId': actorUserId,
      'seatIndex': actor.seatIndex,
      'round': current.round,
      'slammerId': actor.slammerId,
      'arcoriId': arcoriId,
      'result': resolved.result,
      'input': slamInput,
      'outcome': {
        'flippedPieceIds': resolved.flippedPieceIds,
        'impulse': resolved.impulse,
        if (resolved.sim != null) 'sim': resolved.sim,
      },
      'version': nextVersion,
    };

    state = current.copyWith(
      version: nextVersion,
      round: nextRound,
      active: nextActive,
      seats: nextSeats,
      table: nextTable,
      lastEvent: lastEvent,
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
