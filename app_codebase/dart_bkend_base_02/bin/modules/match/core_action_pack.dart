/// Core gameplay actions shared by all match types (SSOT).
library;

import '../../core/errors/app_error.dart';
import 'action_pack.dart';
import 'match_errors.dart';
import 'match_models.dart';
import 'match_store.dart';

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

  /// Stub slam: record lastEvent, rotate active; advance round on wrap.
  static MatchSnapshot _slam({
    required MatchStore store,
    required MatchSnapshot current,
    required String actorUserId,
    required Map<String, dynamic> payload,
  }) {
    if (current.phase != 'playing') {
      throw AppError(matchInvalidRequest, message: 'Match is not playing');
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
    if (wrapping) {
      if (current.round < current.roundsTotal) {
        nextRound = current.round + 1;
        nextActive = {'seatIndex': 0, 'action': 'slam'};
      } else {
        // Last slam of last round — leave cursor on this seat; runner ends.
        nextActive = {
          'seatIndex': actorSeat.seatIndex,
          'action': 'slam',
        };
      }
    }

    final seatIndex = actorSeat.seatIndex;
    final slammerId = actorSeat.slammerId;
    final arcoriId =
        actorSeat.arcoriIds.isNotEmpty ? actorSeat.arcoriIds.first : null;

    return store.bump(current.matchId, (snap) {
      return snap.copyWith(
        round: nextRound,
        active: nextActive,
        lastEvent: {
          'type': 'slam',
          'actorUserId': actorUserId,
          'seatIndex': seatIndex,
          'round': current.round,
          'slammerId': slammerId,
          'arcoriId': arcoriId,
          'result': 'stub',
          'version': snap.version + 1,
        },
      );
    });
  }
}

final coreActionPack = CoreActionPack();
