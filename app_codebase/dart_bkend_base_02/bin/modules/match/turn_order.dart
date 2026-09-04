/// Shared turn-order helpers (first seat + advance after slam).
library;

/// Clamp [firstSeatIndex] into `[0, seatCount)`.
int clampFirstSeatIndex(int firstSeatIndex, int seatCount) {
  if (seatCount <= 0) return 0;
  if (firstSeatIndex < 0) return 0;
  if (firstSeatIndex >= seatCount) return 0;
  return firstSeatIndex;
}

/// Seat order for one round starting at [firstSeatIndex].
List<int> seatOrderForRound({
  required int seatCount,
  required int firstSeatIndex,
}) {
  if (seatCount <= 0) return const [];
  final first = clampFirstSeatIndex(firstSeatIndex, seatCount);
  return [for (var o = 0; o < seatCount; o++) (first + o) % seatCount];
}

/// After a slam by [actorSeatIndex], compute next round + active.
({int round, Map<String, dynamic> active}) advanceTurnActive({
  required int actorSeatIndex,
  required int seatCount,
  required int firstSeatIndex,
  required int round,
  required int roundsTotal,
}) {
  if (seatCount <= 0) {
    return (
      round: round,
      active: <String, dynamic>{'seatIndex': 0, 'action': 'slam'},
    );
  }
  final first = clampFirstSeatIndex(firstSeatIndex, seatCount);
  final nextSeat = (actorSeatIndex + 1) % seatCount;
  final wrapping = nextSeat == first;
  if (!wrapping) {
    return (
      round: round,
      active: <String, dynamic>{'seatIndex': nextSeat, 'action': 'slam'},
    );
  }
  if (round < roundsTotal) {
    return (
      round: round + 1,
      active: <String, dynamic>{'seatIndex': first, 'action': 'slam'},
    );
  }
  // Final slam — park past last physical seat so the turn runner stops.
  return (
    round: round,
    active: <String, dynamic>{'seatIndex': seatCount, 'action': 'slam'},
  );
}
