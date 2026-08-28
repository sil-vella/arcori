import 'package:test/test.dart';

import '../bin/modules/match/slam_resolver.dart';
import '../bin/modules/match/table_pieces.dart';

void main() {
  group('resolveSlam', () {
    Map<String, dynamic> stack() => {
          'pieces': [
            piecePayload(
              pieceId: 'p0',
              designId: 'A',
              ownerUserId: 'u0',
              seatIndex: 0,
              faceUp: false,
              stackIndex: 0,
            ),
            piecePayload(
              pieceId: 'p1',
              designId: 'B',
              ownerUserId: 'u1',
              seatIndex: 1,
              faceUp: false,
              stackIndex: 1,
            ),
          ],
        };

    test('timeout speed misses', () {
      final r = resolveSlam(
        matchId: 'm1',
        version: 1,
        actorSeatIndex: 0,
        input: {
          'speed': 0.0,
          'trajectory': {'dx': 0.0, 'dy': 1.0},
        },
        gameplayAttributes: defaultGameplayAttributes.map(
          (k, v) => MapEntry(k, v),
        ),
        table: stack(),
      );
      expect(r.result, 'miss');
      expect(r.flippedPieceIds, isEmpty);
    });

    test('high impact + speed flips at least one', () {
      final r = resolveSlam(
        matchId: 'm_flip',
        version: 2,
        actorSeatIndex: 0,
        input: {
          'speed': 0.95,
          'trajectory': {'dx': 0.0, 'dy': 1.0},
        },
        gameplayAttributes: {
          'impact': 10,
          'precision': 8,
          'control': 8,
          'recovery': 5,
          'spread': 9,
        },
        table: stack(),
      );
      expect(r.result, 'flip');
      expect(r.flippedPieceIds, isNotEmpty);
      expect(r.scoreDeltas.values.fold<int>(0, (a, b) => a + b), greaterThan(0));
      expect(r.impulse['power'], greaterThan(0.5));
    });

    test('moderate speed on 3-stack often flips more than one', () {
      final three = {
        'pieces': [
          for (var i = 0; i < 3; i++)
            piecePayload(
              pieceId: 'p$i',
              designId: 'D$i',
              ownerUserId: 'u$i',
              seatIndex: i,
              faceUp: false,
              stackIndex: i,
            ),
        ],
      };
      final r = resolveSlam(
        matchId: 'm_3stack',
        version: 1,
        actorSeatIndex: 0,
        input: {
          'speed': 0.6,
          'trajectory': {'dx': 0.0, 'dy': 1.0},
        },
        gameplayAttributes: {
          'impact': 5,
          'precision': 5,
          'control': 5,
          'recovery': 5,
          'spread': 7,
        },
        table: three,
      );
      expect(r.result, 'flip');
      expect(r.flippedPieceIds.length, greaterThanOrEqualTo(1));
    });

    test('punches through face-up top to flip face-down disc below', () {
      final table = {
        'pieces': [
          piecePayload(
            pieceId: 'p0',
            designId: 'A',
            ownerUserId: 'u0',
            seatIndex: 0,
            faceUp: false,
            stackIndex: 0,
          ),
          piecePayload(
            pieceId: 'p1',
            designId: 'B',
            ownerUserId: 'u1',
            seatIndex: 1,
            faceUp: true,
            stackIndex: 1,
          ),
        ],
      };
      final r = resolveSlam(
        matchId: 'm_punch',
        version: 3,
        actorSeatIndex: 1,
        input: {
          'speed': 0.6,
          'trajectory': {'dx': 0.0, 'dy': 1.0},
        },
        gameplayAttributes: defaultGameplayAttributes.map(
          (k, v) => MapEntry(k, v),
        ),
        table: table,
      );
      expect(r.result, 'flip');
      expect(r.flippedPieceIds, ['p0']);
    });

    test('restackFaceDown clears faces', () {
      final flipped = {
        'pieces': [
          piecePayload(
            pieceId: 'p0',
            designId: 'A',
            ownerUserId: 'u0',
            seatIndex: 0,
            faceUp: true,
            stackIndex: 1,
          ),
          piecePayload(
            pieceId: 'p1',
            designId: 'B',
            ownerUserId: 'u1',
            seatIndex: 1,
            faceUp: true,
            stackIndex: 0,
          ),
        ],
      };
      final next = restackFaceDown(flipped);
      final pieces = piecesFromTable(next);
      expect(pieces.every((p) => p['faceUp'] == false), isTrue);
      expect(pieces[0]['stackIndex'], 0);
      expect(pieces[1]['stackIndex'], 1);
    });
  });
}
