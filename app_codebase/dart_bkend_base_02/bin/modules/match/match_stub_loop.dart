/// Auto stub turn runner: 2 rounds × 1 slam per seat, then endMatch.
library;

import 'dart:async';

import '../../utils/dev_logger.dart';
import 'match_models.dart';
import 'match_service.dart';
import 'match_store.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Default delay between stub slams (online broadcast pacing).
const Duration stubMatchStepDelayDefault = Duration(milliseconds: 200);

/// Runs the online stub slam loop for a playing match.
///
/// Applies `slam` as each seat's [MatchSeat.userId], then ends the match.
/// Cancels if the match is already ended or removed mid-loop.
class MatchStubLoop {
  MatchStubLoop({
    required MatchStore store,
    required MatchService service,
    this.stepDelay = stubMatchStepDelayDefault,
  })  : _store = store,
        _service = service;

  final MatchStore _store;
  final MatchService _service;
  Duration stepDelay;

  final Map<String, Future<void>> _inFlight = {};

  /// Kick off stub turns without blocking the caller.
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

  /// Await an in-flight stub loop (tests). Completes immediately if none.
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
        'match: stubLoop start matchId=$matchId '
        'rounds=$roundsTotal seats=$seatCount',
      );
    }

    for (var round = 1; round <= roundsTotal; round++) {
      for (var seatIndex = 0; seatIndex < seatCount; seatIndex++) {
        snap = _store.getSnapshot(matchId);
        if (snap == null || snap.phase != 'playing') {
          if (LOGGING_SWITCH) {
            customlog(
              'match: stubLoop abort matchId=$matchId '
              'phase=${snap?.phase ?? 'missing'}',
            );
          }
          return;
        }
        if (seatIndex >= snap.seats.length) return;

        final actor = snap.seats[seatIndex];
        try {
          _service.action(
            matchId: matchId,
            userId: actor.userId,
            payload: const {'action': 'slam'},
          );
        } catch (e) {
          if (LOGGING_SWITCH) {
            customlog(
              'match: stubLoop slam failed matchId=$matchId '
              'seat=$seatIndex err=$e',
            );
          }
          return;
        }

        if (LOGGING_SWITCH) {
          customlog(
            'match: stubLoop slam round=$round seat=$seatIndex '
            'actor=${actor.userId} slammer=${actor.slammerId}',
          );
        }

        if (stepDelay > Duration.zero) {
          await Future<void>.delayed(stepDelay);
        } else {
          await Future<void>.delayed(Duration.zero);
        }
      }
    }

    snap = _store.getSnapshot(matchId);
    if (snap == null || snap.phase != 'playing') return;

    _service.endInternal(matchId);
    if (LOGGING_SWITCH) {
      customlog('match: stubLoop ended matchId=$matchId');
    }
  }
}
