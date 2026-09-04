import 'package:test/test.dart';

import '../bin/modules/match/turn_order.dart';

void main() {
  group('turn_order', () {
    test('seatOrderForRound wraps from firstSeatIndex', () {
      expect(
        seatOrderForRound(seatCount: 3, firstSeatIndex: 0),
        [0, 1, 2],
      );
      expect(
        seatOrderForRound(seatCount: 3, firstSeatIndex: 2),
        [2, 0, 1],
      );
    });

    test('advanceTurnActive wraps to firstSeatIndex and bumps round', () {
      final mid = advanceTurnActive(
        actorSeatIndex: 2,
        seatCount: 3,
        firstSeatIndex: 2,
        round: 1,
        roundsTotal: 2,
      );
      expect(mid.active['seatIndex'], 0);
      expect(mid.round, 1);

      final wrap = advanceTurnActive(
        actorSeatIndex: 1,
        seatCount: 3,
        firstSeatIndex: 2,
        round: 1,
        roundsTotal: 2,
      );
      expect(wrap.active['seatIndex'], 2);
      expect(wrap.round, 2);

      final end = advanceTurnActive(
        actorSeatIndex: 1,
        seatCount: 3,
        firstSeatIndex: 2,
        round: 2,
        roundsTotal: 2,
      );
      expect(end.active['seatIndex'], 3);
      expect(end.round, 2);
    });
  });
}
