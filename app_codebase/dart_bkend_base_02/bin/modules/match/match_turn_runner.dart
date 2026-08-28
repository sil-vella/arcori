/// Turn-based stub runner: wait for human slam input (5s) or pace AI slams.
library;

import 'dart:async';
import 'dart:math';

import '../../utils/dev_logger.dart';
import 'match_models.dart';
import 'match_service.dart';
import 'match_store.dart';
import 'slam_input.dart';
import 'turn_pacing.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Online turn runner — replaces instant 200ms stub burst.
class MatchTurnRunner {
  MatchTurnRunner({
    required MatchStore store,
    required MatchService service,
    this.matchStartGrace = matchStartGraceDefault,
    this.turnTimeout = turnTimeoutDefault,
    this.aiDelayMin = aiDelayMinDefault,
    this.aiDelayMax = aiDelayMaxDefault,
    this.aiMissProbability = aiMissProbabilityDefault,
    Random? random,
  })  : _store = store,
        _service = service,
        _rng = random ?? Random();

  final MatchStore _store;
  final MatchService _service;
  final Random _rng;

  Duration matchStartGrace;
  Duration turnTimeout;
  Duration aiDelayMin;
  Duration aiDelayMax;
  double aiMissProbability;

  final Map<String, Future<void>> _inFlight = {};

  void schedule(String matchId) {
    if (_inFlight.containsKey(matchId)) return;
    final future = run(matchId);
    _inFlight[matchId] = future;
    unawaited(
      future.whenComplete(() {
        _inFlight.remove(matchId);
      }),
    );
  }

  Future<void> waitFor(String matchId) {
    return _inFlight[matchId] ?? Future<void>.value();
  }

  Future<void> run(String matchId) async {
    var snap = _store.getSnapshot(matchId);
    if (snap == null || snap.phase != 'playing') return;

    final roundsTotal = snap.roundsTotal;
    final seatCount = snap.seats.length;
    if (seatCount == 0) return;

    if (LOGGING_SWITCH) {
      customlog(
        'match: turnRunner start matchId=$matchId '
        'rounds=$roundsTotal seats=$seatCount '
        'grace=${matchStartGrace.inSeconds}s timeout=${turnTimeout.inSeconds}s',
      );
    }

    await _waitMatchGrace(matchId);

    for (var round = 1; round <= roundsTotal; round++) {
      for (var seatIndex = 0; seatIndex < seatCount; seatIndex++) {
        snap = _store.getSnapshot(matchId);
        if (snap == null || snap.phase != 'playing') {
          if (LOGGING_SWITCH) {
            customlog(
              'match: turnRunner abort matchId=$matchId '
              'phase=${snap?.phase ?? 'missing'}',
            );
          }
          return;
        }
        if (seatIndex >= snap.seats.length) return;

        final actor = snap.seats[seatIndex];
        if (actor.kind == 'human') {
          await _waitHumanTurn(
            matchId: matchId,
            seatIndex: seatIndex,
            actorUserId: actor.userId,
          );
        } else {
          await _runAiTurn(
            matchId: matchId,
            seatIndex: seatIndex,
            actorUserId: actor.userId,
          );
        }
      }
    }

    snap = _store.getSnapshot(matchId);
    if (snap == null || snap.phase != 'playing') return;

    _service.endInternal(matchId);
    if (LOGGING_SWITCH) {
      customlog('match: turnRunner ended matchId=$matchId');
    }
  }

  Future<void> _waitMatchGrace(String matchId) async {
    if (matchStartGrace <= Duration.zero) return;

    if (LOGGING_SWITCH) {
      customlog('match: turnRunner grace wait matchId=$matchId');
    }

    while (true) {
      final snap = _store.getSnapshot(matchId);
      if (snap == null || snap.phase != 'playing') return;
      final ends = _graceEndsAt(snap);
      if (ends == null) return;
      final remaining = ends.difference(DateTime.now().toUtc());
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        remaining < turnPollInterval ? remaining : turnPollInterval,
      );
    }

    _service.clearTurnGrace(matchId);
    if (LOGGING_SWITCH) {
      customlog('match: turnRunner grace ended matchId=$matchId');
    }
  }

  DateTime? _graceEndsAt(MatchSnapshot snap) {
    final raw = snap.active?['graceEndsAt']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> _waitHumanTurn({
    required String matchId,
    required int seatIndex,
    required String actorUserId,
  }) async {
    if (LOGGING_SWITCH) {
      customlog(
        'match: turnRunner human wait matchId=$matchId '
        'seat=$seatIndex user=$actorUserId',
      );
    }
    await _waitUntilTurnAdvancesOrTimeout(
      matchId: matchId,
      seatIndex: seatIndex,
      timeout: turnTimeout,
    );
    final snap = _store.getSnapshot(matchId);
    if (snap == null || snap.phase != 'playing') return;
    if (_activeSeatIndex(snap) == seatIndex) {
      _applySlam(
        matchId: matchId,
        actorUserId: actorUserId,
        input: timeoutSlamInput(),
        label: 'human_timeout',
      );
    }
  }

  Future<void> _runAiTurn({
    required String matchId,
    required int seatIndex,
    required String actorUserId,
  }) async {
    final miss = rollAiMiss(_rng, probability: aiMissProbability);
    if (miss) {
      if (LOGGING_SWITCH) {
        customlog(
          'match: turnRunner ai miss matchId=$matchId seat=$seatIndex',
        );
      }
      await _waitUntilTurnAdvancesOrTimeout(
        matchId: matchId,
        seatIndex: seatIndex,
        timeout: turnTimeout,
      );
      final snap = _store.getSnapshot(matchId);
      if (snap == null || snap.phase != 'playing') return;
      if (_activeSeatIndex(snap) == seatIndex) {
        _applySlam(
          matchId: matchId,
          actorUserId: actorUserId,
          input: timeoutSlamInput(source: 'ai_timeout'),
          label: 'ai_timeout',
        );
      }
      return;
    }

    final delay = randomAiDelay(_rng, min: aiDelayMin, max: aiDelayMax);
    if (LOGGING_SWITCH) {
      customlog(
        'match: turnRunner ai delay matchId=$matchId '
        'seat=$seatIndex ms=${delay.inMilliseconds}',
      );
    }
    await Future<void>.delayed(delay);

    final snap = _store.getSnapshot(matchId);
    if (snap == null || snap.phase != 'playing') return;
    if (_activeSeatIndex(snap) != seatIndex) return;

    _applySlam(
      matchId: matchId,
      actorUserId: actorUserId,
      input: syntheticAiSlamInput(_rng),
      label: 'ai_synthetic',
    );
  }

  Future<void> _waitUntilTurnAdvancesOrTimeout({
    required String matchId,
    required int seatIndex,
    required Duration timeout,
  }) async {
    if (timeout <= Duration.zero) {
      return;
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final snap = _store.getSnapshot(matchId);
      if (snap == null || snap.phase != 'playing') return;
      if (_activeSeatIndex(snap) != seatIndex) return;
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        remaining < turnPollInterval ? remaining : turnPollInterval,
      );
    }
  }

  int? _activeSeatIndex(MatchSnapshot snap) {
    final active = snap.active?['seatIndex'];
    return active is int ? active : null;
  }

  void _applySlam({
    required String matchId,
    required String actorUserId,
    required Map<String, dynamic> input,
    required String label,
  }) {
    try {
      _service.action(
        matchId: matchId,
        userId: actorUserId,
        payload: {
          'action': 'slam',
          'input': input,
        },
      );
      if (LOGGING_SWITCH) {
        customlog(
          'match: turnRunner slam $label matchId=$matchId '
          'actor=$actorUserId speed=${input['speed']}',
        );
      }
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog(
          'match: turnRunner slam failed matchId=$matchId '
          'label=$label err=$e',
        );
      }
    }
  }
}
