/// Core gameplay actions shared by all match types (SSOT).
library;

import '../../core/errors/app_error.dart';
import '../../utils/dev_logger.dart';
import 'action_pack.dart';
import 'match_errors.dart';
import 'match_models.dart';
import 'match_store.dart';
import 'slam_input.dart';
import 'slam_resolver.dart';
import 'table_pieces.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class CoreActionPack implements MatchActionPack {
  @override
  Set<String> get actionNames => const {'slam'};

  @override
  MatchActionHandler? handlerFor(String action) {
    switch (action) {
      case 'slam':
        return _slam;
      default:
        return null;
    }
  }

  /// Slam: resolve flips from input + frozen attrs, rotate active, restack on round.
  static MatchSnapshot _slam({
    required MatchStore store,
    required MatchSnapshot current,
    required String actorUserId,
    required Map<String, dynamic> payload,
  }) {
    if (current.phase != 'playing') {
      throw AppError(matchInvalidRequest, message: 'Match is not playing');
    }
    if (activeInGracePeriod(current.active)) {
      throw AppError(matchNotYourTurn, message: 'Match start grace');
    }
    final activeSeat = current.active?['seatIndex'];
    MatchSeat? actorSeat;
    for (final s in current.seats) {
      if (s.userId == actorUserId) {
        actorSeat = s;
        break;
      }
    }
    if (actorSeat == null) {
      throw AppError(matchForbidden, message: 'Not a seat in this match');
    }
    if (activeSeat is int && activeSeat != actorSeat.seatIndex) {
      throw AppError(matchNotYourTurn);
    }

    final seatCount = current.seats.length;
    final wrapping =
        seatCount > 0 && actorSeat.seatIndex == seatCount - 1;
    final nextSeatIndex = wrapping ? 0 : actorSeat.seatIndex + 1;

    var nextRound = current.round;
    var nextActive = <String, dynamic>{
      'seatIndex': nextSeatIndex,
      'action': 'slam',
    };
    var advancingRound = false;
    if (wrapping) {
      if (current.round < current.roundsTotal) {
        nextRound = current.round + 1;
        nextActive = {'seatIndex': 0, 'action': 'slam'};
        advancingRound = true;
      } else {
        // Final slam of the match — move active past the last seat so the
        // turn runner does not wait/timeout again on the same seat.
        nextActive = {
          'seatIndex': seatCount,
          'action': 'slam',
        };
      }
    }

    final seatIndex = actorSeat.seatIndex;
    final slammerId = actorSeat.slammerId;
    final arcoriId =
        actorSeat.arcoriIds.isNotEmpty ? actorSeat.arcoriIds.first : null;

    final slamInput = parseSlamInput(payload) ?? timeoutSlamInput();

    final runtime = store.getRuntime(current.matchId);
    final frozen = runtime?.catalogById[slammerId];
    Map<String, dynamic>? attrs;
    if (frozen != null && frozen['gameplayAttributes'] is Map) {
      attrs = Map<String, dynamic>.from(
        frozen['gameplayAttributes'] as Map,
      );
    }

    final resolved = resolveSlam(
      matchId: current.matchId,
      version: current.version,
      actorSeatIndex: seatIndex,
      input: slamInput,
      gameplayAttributes: attrs,
      table: current.table,
    );

    if (LOGGING_SWITCH) {
      customlog(
        'match: slam resolve matchId=${current.matchId} '
        'result=${resolved.result} flips=${resolved.flippedPieceIds.length} '
        'power=${resolved.impulse['power']}',
      );
    }

    final scoreByUser = <String, int>{
      for (final s in current.seats) s.userId: s.score,
    };
    for (final e in resolved.scoreDeltas.entries) {
      scoreByUser[e.key] = (scoreByUser[e.key] ?? 0) + e.value;
    }
    final nextSeats = current.seats
        .map(
          (s) => s.copyWith(score: scoreByUser[s.userId] ?? s.score),
        )
        .toList();

    var nextTable = <String, dynamic>{'pieces': resolved.pieces};
    if (advancingRound) {
      nextTable = restackFaceDown(nextTable);
    }

    return store.bump(current.matchId, (snap) {
      final lastEvent = <String, dynamic>{
        'type': 'slam',
        'actorUserId': actorUserId,
        'seatIndex': seatIndex,
        'round': current.round,
        'slammerId': slammerId,
        'arcoriId': arcoriId,
        'result': resolved.result,
        'input': slamInput,
        'outcome': {
          'flippedPieceIds': resolved.flippedPieceIds,
          'impulse': resolved.impulse,
        },
        'version': snap.version + 1,
      };
      return snap.copyWith(
        round: nextRound,
        active: nextActive,
        seats: nextSeats,
        table: nextTable,
        lastEvent: lastEvent,
      );
    });
  }
}

final coreActionPack = CoreActionPack();
