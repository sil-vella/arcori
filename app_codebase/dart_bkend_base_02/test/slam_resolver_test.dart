import 'dart:math';

import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

import '../bin/modules/match/slam_input.dart';
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
          'aim': {'x': 0.0, 'z': 0.0},
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

    test('aim outside stack footprint misses with no kick', () {
      final r = resolveSlam(
        matchId: 'm_aim_miss',
        version: 1,
        actorSeatIndex: 0,
        input: {
          'speed': 0.95,
          'aim': {'x': kSlamAimHitRadius * 3, 'z': 0.0},
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
      expect(r.result, 'miss');
      expect(r.flippedPieceIds, isEmpty);
      expect((r.sim!['frames'] as List), isEmpty);
      expect(aimOutsideStackFootprint(kSlamAimHitRadius * 3, 0), isTrue);
    });

    test('high impact + speed flips at least one', () {
      final r = resolveSlam(
        matchId: 'm_flip',
        version: 2,
        actorSeatIndex: 0,
        input: {
          'speed': 0.95,
          'aim': {'x': 0.0, 'z': 0.0},
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
          'aim': {'x': 0.0, 'z': 0.0},
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
          'aim': {'x': 0.0, 'z': 0.0},
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
          'aim': {'x': 0.0, 'z': 0.0},
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

    test('starter slam kicks every face-down disc in a 3-stack', () {
      final r = runSlamPhysics(
        pieces: [
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
        dx: 0.0,
        dy: -1.0,
        speed: 1.0,
        power: 0.5,
        maxAffect: 2,
        rng: Random(7),
      );
      final frames = r.sim['frames'] as List;
      expect(frames.length, greaterThan(2));
      final start = (frames[0] as Map)['p'] as List;
      final early = (frames[2] as Map)['p'] as List;
      var spun = 0;
      for (var i = 0; i < 3; i++) {
        final a = start[i] as List;
        final b = early[i] as List;
        var dq = 0.0;
        for (var k = 4; k <= 7; k++) {
          dq += ((a[k] as num) - (b[k] as num)).abs();
        }
        if (dq > 0.02) spun++;
      }
      expect(spun, 3);
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
          'aim': {'x': 0.0, 'z': 0.0},
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
          'aim': {'x': 0.0, 'z': 0.0},
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
          'aim': {'x': 0.0, 'z': 0.0},
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

    test('restingOrientationFrom keeps in-plane yaw', () {
      const yaw = 0.7;
      final spun = Quaternion.axisAngle(Vector3(0, 1, 0), yaw);
      final rest = restingOrientationFrom(spun, faceUp: true);
      expect(isFaceUpOrientation(rest), isTrue);
      final x = rest.rotated(Vector3(1, 0, 0));
      expect(atan2(-x.z, x.x), closeTo(yaw, 0.05));

      final flipped = spun * Quaternion.axisAngle(Vector3(1, 0, 0), pi);
      final down = restingOrientationFrom(flipped, faceUp: false);
      expect(isFaceUpOrientation(down), isFalse);
      final dx = down.rotated(Vector3(1, 0, 0));
      expect(atan2(-dx.z, dx.x), closeTo(yaw, 0.05));
    });

    test('restingOrientationFrom is exactly flat on the table', () {
      const yaw = 0.7;
      final tipped = Quaternion.axisAngle(Vector3(0, 1, 0), yaw) *
          Quaternion.axisAngle(Vector3(1, 0, 0), 0.4);
      final up = restingOrientationFrom(tipped, faceUp: true);
      expect(isFlatOnTable(up), isTrue);
      expect(isFaceUpOrientation(up), isTrue);
      final x = up.rotated(Vector3(1, 0, 0));
      expect(atan2(-x.z, x.x), closeTo(yaw, 0.08));

      final down = restingOrientationFrom(tipped, faceUp: false);
      expect(isFlatOnTable(down), isTrue);
      expect(isFaceUpOrientation(down), isFalse);
    });

    test('stack start and settled poses lie flat', () {
      final r = runSlamPhysics(
        pieces: [
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
        dx: 0.4,
        dy: -0.8,
        speed: 0.85,
        power: 0.9,
        maxAffect: 3,
        rng: Random(42),
      );
      final frames = r.sim['frames'] as List;
      final first = (frames.first as Map)['p'] as List;
      final last = (frames.last as Map)['p'] as List;
      var spun = 0;
      for (final row in first) {
        final p = row as List;
        final q = Quaternion(
          (p[4] as num).toDouble(),
          (p[5] as num).toDouble(),
          (p[6] as num).toDouble(),
          (p[7] as num).toDouble(),
        )..normalize();
        expect(isFlatOnTable(q), isTrue);
      }
      for (final row in last) {
        final p = row as List;
        final qx = (p[4] as num).toDouble();
        final qy = (p[5] as num).toDouble();
        final qz = (p[6] as num).toDouble();
        final qw = (p[7] as num).toDouble();
        final q = Quaternion(qx, qy, qz, qw)..normalize();
        expect(isFlatOnTable(q), isTrue);
        final identity = qx.abs() + qy.abs() + qz.abs() < 0.08 && qw.abs() > 0.95;
        final downX = qx.abs() > 0.95 && qy.abs() + qz.abs() < 0.08;
        if (!identity && !downX) spun++;
      }
      expect(spun, greaterThan(0));
    });

    test('tumble does not linger on the rim for most of the timeline', () {
      final r = runSlamPhysics(
        pieces: [
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
        dx: 0.35,
        dy: -0.75,
        speed: 0.8,
        power: 0.75,
        maxAffect: 3,
        rng: Random(7),
      );
      final frames = r.sim['frames'] as List;
      final start = (frames.length * 0.65).floor();
      var rim = 0;
      var total = 0;
      for (var f = start; f < frames.length; f++) {
        final poses = (frames[f] as Map)['p'] as List;
        for (final row in poses) {
          final p = row as List;
          final q = Quaternion(
            (p[4] as num).toDouble(),
            (p[5] as num).toDouble(),
            (p[6] as num).toDouble(),
            (p[7] as num).toDouble(),
          )..normalize();
          final ny = q.rotated(Vector3(0, 1, 0)).y.abs();
          total++;
          if (ny < 0.35) rim++;
        }
      }
      expect(total, greaterThan(0));
      expect(rim / total, lessThan(0.35));
    });

    test('tumble shows flips in the air before flatten', () {
      final r = runSlamPhysics(
        pieces: [
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
        dx: 0.35,
        dy: -0.75,
        speed: 0.8,
        power: 0.75,
        maxAffect: 3,
        rng: Random(7),
      );
      final frames = r.sim['frames'] as List;
      final end = (frames.length * 0.45).ceil().clamp(1, frames.length);
      var tipped = 0;
      for (var f = 0; f < end; f++) {
        final poses = (frames[f] as Map)['p'] as List;
        for (final row in poses) {
          final p = row as List;
          final q = Quaternion(
            (p[4] as num).toDouble(),
            (p[5] as num).toDouble(),
            (p[6] as num).toDouble(),
            (p[7] as num).toDouble(),
          )..normalize();
          final ny = q.rotated(Vector3(0, 1, 0)).y.abs();
          if (ny < 0.55) tipped++;
        }
      }
      expect(tipped, greaterThan(0));
    });
  });
}
