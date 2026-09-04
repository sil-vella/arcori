import 'dart:math';

import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

import '../bin/modules/match/slam_physics_world.dart';
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

    test('weak slam counts but barely moves and usually does not wipe the stack', () {
      final r = resolveSlam(
        matchId: 'm_weak',
        version: 1,
        actorSeatIndex: 0,
        input: {
          'speed': 0.12,
          'trajectory': {'dx': 0.0, 'dy': 1.0},
        },
        gameplayAttributes: {
          'impact': 5,
          'precision': 5,
          'control': 5,
          'recovery': 5,
          'spread': 5,
        },
        table: stack(),
      );
      expect(r.impulse['power'], lessThan(0.15));
      expect(r.sim, isNotNull);
      final frames = r.sim!['frames'] as List;
      expect(frames.length, greaterThan(1));
      // Continuous physics: weak kick should not wipe a 2-stack.
      expect(r.flippedPieceIds.length, lessThan(2));
    });

    test('mid power on 3-stack is not always all-or-nothing', () {
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
      final flipCounts = <int>[];
      for (var v = 1; v <= 12; v++) {
        final r = resolveSlam(
          matchId: 'm_partial',
          version: v,
          actorSeatIndex: 0,
          input: {
            'speed': 0.55,
            'trajectory': {'dx': 0.15, 'dy': 1.0},
          },
          gameplayAttributes: {
            'impact': 6,
            'precision': 5,
            'control': 5,
            'recovery': 5,
            'spread': 6,
          },
          table: three,
        );
        flipCounts.add(r.flippedPieceIds.length);
      }
      // Across seeds, expect variety (not always 0 and not always 3).
      expect(flipCounts.any((n) => n < 3), isTrue);
      expect(flipCounts.toSet().length, greaterThan(1));
    });

    test('strong slam on 3-stack can flip at least one', () {
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
          'speed': 0.9,
          'trajectory': {'dx': 0.0, 'dy': 1.0},
        },
        gameplayAttributes: {
          'impact': 9,
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
          'speed': 0.95,
          'trajectory': {'dx': 0.0, 'dy': 1.0},
        },
        gameplayAttributes: {
          'impact': 10,
          'precision': 5,
          'control': 5,
          'recovery': 5,
          'spread': 8,
        },
        table: table,
      );
      expect(r.result, 'flip');
      expect(r.flippedPieceIds, contains('p0'));
      expect(r.flippedPieceIds, isNot(contains('p1')));
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

    test('same seed yields identical sim frames', () {
      Map<String, dynamic> input() => {
            'speed': 0.8,
            'trajectory': {'dx': 0.2, 'dy': 1.0},
          };
      Map<String, dynamic> attrs() => {
            'impact': 8,
            'precision': 7,
            'control': 6,
            'recovery': 5,
            'spread': 8,
          };
      final a = resolveSlam(
        matchId: 'm_det',
        version: 4,
        actorSeatIndex: 0,
        input: input(),
        gameplayAttributes: attrs(),
        table: stack(),
      );
      final b = resolveSlam(
        matchId: 'm_det',
        version: 4,
        actorSeatIndex: 0,
        input: input(),
        gameplayAttributes: attrs(),
        table: stack(),
      );
      expect(a.result, b.result);
      expect(a.flippedPieceIds, b.flippedPieceIds);
      expect(a.sim?['frames'].toString(), b.sim?['frames'].toString());
    });

    test('angled kick moves more than one disc (collision transfer)', () {
      final r = resolveSlam(
        matchId: 'm_collide',
        version: 1,
        actorSeatIndex: 0,
        input: {
          'speed': 0.9,
          'trajectory': {'dx': 0.7, 'dy': 1.0},
        },
        gameplayAttributes: {
          'impact': 9,
          'precision': 5,
          'control': 5,
          'recovery': 5,
          'spread': 9,
        },
        table: stack(),
      );
      expect(r.sim, isNotNull);
      expect(r.sim!['space'], 'xyzq');
      final frames = r.sim!['frames'] as List;
      expect(frames.length, greaterThan(2));
      final first = frames.first as Map;
      final last = frames.last as Map;
      final firstPoses = first['p'] as List;
      final lastPoses = last['p'] as List;
      expect((firstPoses.first as List).length, greaterThanOrEqualTo(8));
      var moved = 0;
      for (var i = 0; i < firstPoses.length; i++) {
        final a = firstPoses[i] as List;
        final b = lastPoses[i] as List;
        final dx = ((a[1] as num) - (b[1] as num)).abs();
        final dy = ((a[2] as num) - (b[2] as num)).abs();
        final dz = ((a[3] as num) - (b[3] as num)).abs();
        if (dx + dy + dz > 0.05) moved++;
      }
      expect(moved, greaterThanOrEqualTo(2));
    });

    test('isFaceUpOrientation recognizes face normal vs world up', () {
      expect(isFaceUpOrientation(faceOrientation(faceUp: true)), isTrue);
      expect(isFaceUpOrientation(faceOrientation(faceUp: false)), isFalse);
      expect(
        isFaceUpOrientation(Quaternion.axisAngle(Vector3(1, 0, 0), pi / 2)),
        isFalse,
      );
    });
  });
}
