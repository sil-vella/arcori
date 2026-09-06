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
import 'turn_order.dart';
import 'turn_pacing.dart';

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
    if (activeInputLocked(current.active)) {
      throw AppError(matchNotYourTurn, message: 'Slam anim in progress');
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
    final advanced = advanceTurnActive(
      actorSeatIndex: actorSeat.seatIndex,
      seatCount: seatCount,
      firstSeatIndex: current.firstSeatIndex,
      round: current.round,
      roundsTotal: current.roundsTotal,
    );
    final nextRound = advanced.round;

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
      final frames = resolved.sim?['frames'];
      final frameCount = frames is List ? frames.length : 0;
      final steps = resolved.sim?['steps'];
      final holdMs = resolved.sim?['animHoldMs'];
      customlog(
        'match: slam resolve matchId=${current.matchId} '
        'result=${resolved.result} flips=${resolved.flippedPieceIds.length} '
        'power=${resolved.impulse['power']} simFrames=$frameCount '
        'steps=$steps animHoldMs=$holdMs '
        'flippedIds=${resolved.flippedPieceIds}',
      );
    }

    final holdMs = resolved.sim?['animHoldMs'] is num
        ? (resolved.sim!['animHoldMs'] as num).round()
        : postSlamAnimHoldDefault.inMilliseconds;
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
        .map(
          (s) => s.copyWith(score: scoreByUser[s.userId] ?? s.score),
        )
        .toList();

    // Always restack face-down after a slam so the next seat starts clean.
    final nextTable = restackFaceDown({'pieces': resolved.pieces});
    if (LOGGING_SWITCH) {
      final n = piecesFromTable(nextTable).length;
      customlog(
        'match: restack faceDown n=$n '
        'wasFlipped=${resolved.flippedPieceIds}',
      );
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
          if (resolved.sim != null) 'sim': resolved.sim,
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
