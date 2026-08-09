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

  /// Stub slam: set lastEvent and rotate active seat. No score/physics yet.
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

    final nextSeatIndex =
        (actorSeat.seatIndex + 1) % current.seats.length;

    return store.bump(current.matchId, (snap) {
      return snap.copyWith(
        active: {
          'seatIndex': nextSeatIndex,
          'action': 'slam',
        },
        lastEvent: {
          'type': 'slam',
          'actorUserId': actorUserId,
          'result': 'stub',
          'version': snap.version + 1,
        },
      );
    });
  }
}

final coreActionPack = CoreActionPack();
